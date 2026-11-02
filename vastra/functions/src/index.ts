import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import {
  GARMENT_CATEGORIES,
  createClothV4Task,
  createSodTask,
  getClothV4Task,
  waitForTask,
  uploadBufferToYouCam,
  type GarmentCategory,
} from "./services/youcam";
import { getCachedWeather, type WeatherSnapshot } from "./services/weatherstack";
import { extractJson, geminiGenerateFromImage, geminiGenerateText } from "./services/gemini";
import { downloadRemoteImage, persistImage, persistRemoteImage } from "./services/persist";
import { optimiseCutout } from "./services/images";
import { assertOwnedPath, downloadStorageFile } from "./services/storage";

initializeApp();
setGlobalOptions({ region: "europe-west1", maxInstances: 20 });

const youcamApiKey = defineSecret("YOUCAM_API_KEY");
const geminiApiKey = defineSecret("GEMINI_API_KEY");
const weatherstackApiKey = defineSecret("WEATHERSTACK_API_KEY");

const YOUCAM_FILE_TTL_MS = 25 * 24 * 60 * 60 * 1000;
const WARDROBE_CATEGORIES = [
  "tops",
  "trousers",
  "skirts",
  "dresses",
  "outerwear",
  "shoes",
  "bags",
  "accessories",
];

type ReqLike = { headers: Record<string, unknown> };
type ResLike = {
  setHeader: (k: string, v: string) => void;
  status: (code: number) => { json: (body: unknown) => void };
};

class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

async function requireUser(req: ReqLike) {
  const header = String(req.headers.authorization || "");
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) throw new HttpError(401, "Please sign in again");
  try {
    return await getAuth().verifyIdToken(token);
  } catch {
    throw new HttpError(401, "Your session expired — please sign in again");
  }
}

function send(res: ResLike, status: number, body: unknown) {
  res.setHeader("Cache-Control", "no-store");
  res.status(status).json(body);
}

function fail(res: ResLike, error: unknown) {
  const status = (error as { status?: number })?.status ?? 500;
  const message = error instanceof Error ? error.message : "Something went wrong";
  if (status >= 500) console.error(error);
  send(res, status, { error: message });
}

function userDoc(uid: string) {
  return getFirestore().collection("users").doc(uid);
}

export const health = onRequest({ cors: true, invoker: "public" }, async (_req, res) => {
  send(res, 200, { ok: true, service: "vastra-functions", version: "2.0.0" });
});

export const getWeather = onRequest(
  { cors: true, invoker: "public", secrets: [weatherstackApiKey] },
  async (req, res) => {
    try {
      await requireUser(req);
      const body = (req.body || {}) as { city?: string };
      const city = String(req.query.city || body.city || "").trim();
      if (!city) throw new HttpError(400, "city is required");
      send(res, 200, { weather: await getCachedWeather(city) });
    } catch (error) {
      fail(res, error);
    }
  },
);

type ClosetDoc = {
  name?: string;
  category?: string;
  imagePath?: string;
  imageUrl?: string;
  cutoutUrl?: string | null;
  cutoutPath?: string | null;
  cutoutFor?: string | null;
  cutoutThumbUrl?: string | null;
  cutoutThumbPath?: string | null;
  youcamFileId?: string;
  youcamFileAt?: number;
};

type ProfileDoc = {
  tryOnPhotoPath?: string | null;
  youcamPerson?: { path: string; fileId: string; at: number };
};

/** YouCam file id for the user's try-on portrait, re-uploaded only when it changes or expires. */
async function youcamPortraitFile(uid: string, user: ProfileDoc): Promise<string> {
  const personPath = user.tryOnPhotoPath;
  if (!personPath) throw new HttpError(400, "Add your try-on portrait first");
  assertOwnedPath(uid, personPath);
  const cached = user.youcamPerson;
  if (cached && cached.path === personPath && Date.now() - cached.at < YOUCAM_FILE_TTL_MS) return cached.fileId;
  const fileId = await uploadBufferToYouCam(await downloadStorageFile(personPath));
  await userDoc(uid).set({ youcamPerson: { path: personPath, fileId, at: Date.now() } }, { merge: true });
  return fileId;
}

/** YouCam file id for a closet photo, cached on the item for 25 days. */
async function youcamItemFile(
  uid: string,
  itemRef: FirebaseFirestore.DocumentReference,
  item: ClosetDoc,
): Promise<string> {
  if (!item.imagePath) throw new HttpError(404, "That closet piece no longer exists");
  assertOwnedPath(uid, item.imagePath);
  if (item.youcamFileId && item.youcamFileAt && Date.now() - item.youcamFileAt < YOUCAM_FILE_TTL_MS) {
    return item.youcamFileId;
  }
  const fileId = await uploadBufferToYouCam(await downloadStorageFile(item.imagePath));
  await itemRef.update({ youcamFileId: fileId, youcamFileAt: Date.now() });
  return fileId;
}

/** YouCam background removal on an uploaded file, saved as a PNG in the user's Storage. */
async function cutout(uid: string, fileId: string) {
  const url = await waitForTask("sod", await createSodTask(fileId), 90_000);
  return saveCutout(uid, (await downloadRemoteImage(url)).buffer);
}

/** Saves a trimmed WebP cutout plus a small thumbnail for grids. */
async function saveCutout(uid: string, png: Buffer) {
  const { full, thumb } = await optimiseCutout(png);
  const [saved, savedThumb] = await Promise.all([
    persistImage({ userId: uid, folder: "cutouts", buffer: full, contentType: "image/webp" }),
    persistImage({ userId: uid, folder: "cutouts", buffer: thumb, contentType: "image/webp" }),
  ]);
  return { ...saved, thumbPath: savedThumb.path, thumbUrl: savedThumb.url };
}

/** Cutouts made before WebP optimisation are PNGs; re-encode them without spending YouCam units. */
async function reoptimiseCutout(uid: string, path: string) {
  assertOwnedPath(uid, path);
  return saveCutout(uid, (await downloadStorageFile(path)).buffer);
}

const isOptimised = (path?: string | null) => Boolean(path && path.endsWith(".webp"));

async function deleteStorageQuietly(path?: string | null) {
  if (!path) return;
  try {
    await getStorage().bucket().file(path).delete();
  } catch {
    // already gone
  }
}

/**
 * Starts a YouCam cloth-v4 try-on.
 * Body: { wardrobeItemId? | garmentPath? | garmentImageUrl?, garmentCategory?, title?, garmentPreviewUrl? }
 * The person photo comes from the user's profile (tryOnPhotoPath) unless personImageUrl is passed.
 */
export const startTryOn = onRequest(
  { cors: true, invoker: "public", timeoutSeconds: 120, memory: "512MiB", secrets: [youcamApiKey] },
  async (req, res) => {
    try {
      if (req.method !== "POST") throw new HttpError(405, "POST only");
      const decoded = await requireUser(req);
      const uid = decoded.uid;
      const body = (req.body || {}) as {
        personImageUrl?: string;
        wardrobeItemId?: string | null;
        garmentPath?: string | null;
        garmentImageUrl?: string | null;
        garmentPreviewUrl?: string | null;
        garmentCategory?: string;
        title?: string;
        productId?: string | null;
        outfitId?: string | null;
      };

      const garmentCategory = (GARMENT_CATEGORIES as string[]).includes(body.garmentCategory || "")
        ? (body.garmentCategory as GarmentCategory)
        : "auto";

      const userRef = userDoc(uid);
      const user = ((await userRef.get()).data() || {}) as {
        tryOnPhotoPath?: string | null;
        youcamPerson?: { path: string; fileId: string; at: number };
      };

      let srcFileId: string | undefined;
      let srcFileUrl: string | undefined;
      if (user.tryOnPhotoPath) {
        srcFileId = await youcamPortraitFile(uid, user);
      } else if (body.personImageUrl) {
        srcFileUrl = body.personImageUrl;
      } else {
        throw new HttpError(400, "Add your try-on portrait first");
      }

      let refFileId: string | undefined;
      let refFileUrl: string | undefined;
      let previewUrl = body.garmentPreviewUrl || body.garmentImageUrl || null;

      if (body.wardrobeItemId) {
        const itemRef = userRef.collection("wardrobeItems").doc(body.wardrobeItemId);
        const item = (await itemRef.get()).data() as ClosetDoc | undefined;
        if (!item?.imagePath) throw new HttpError(404, "That closet piece no longer exists");
        previewUrl = previewUrl || item.imageUrl || null;
        refFileId = await youcamItemFile(uid, itemRef, item);
      } else if (body.garmentPath) {
        assertOwnedPath(uid, body.garmentPath);
        refFileId = await uploadBufferToYouCam(await downloadStorageFile(body.garmentPath));
      } else if (body.garmentImageUrl) {
        refFileUrl = body.garmentImageUrl;
      } else {
        throw new HttpError(400, "Pick a garment to try on");
      }

      const taskId = await createClothV4Task({
        srcFileId,
        srcFileUrl,
        refFileId,
        refFileUrl,
        garmentCategory,
      });

      const jobRef = userRef.collection("tryOnJobs").doc();
      const now = Date.now();
      await jobRef.set({
        id: jobRef.id,
        userId: uid,
        title: body.title || "Try-on",
        productId: body.productId ?? null,
        wardrobeItemId: body.wardrobeItemId ?? null,
        outfitId: body.outfitId ?? null,
        garmentCategory,
        garmentImageUrl: previewUrl,
        status: "processing",
        providerTaskId: taskId,
        resultPath: null,
        resultUrl: null,
        errorCode: null,
        errorMessage: null,
        unitsSpent: 2,
        createdAt: now,
        updatedAt: now,
        completedAt: null,
        createdAtServer: FieldValue.serverTimestamp(),
      });

      send(res, 200, { jobId: jobRef.id, taskId, status: "processing" });
    } catch (error) {
      fail(res, error);
    }
  },
);

export const pollTryOn = onRequest(
  { cors: true, invoker: "public", timeoutSeconds: 120, memory: "512MiB", secrets: [youcamApiKey] },
  async (req, res) => {
    try {
      const decoded = await requireUser(req);
      const body = (req.body || {}) as { jobId?: string };
      const jobId = String(req.query.jobId || body.jobId || "");
      if (!jobId) throw new HttpError(400, "jobId required");

      const jobRef = userDoc(decoded.uid).collection("tryOnJobs").doc(jobId);
      const snap = await jobRef.get();
      if (!snap.exists) throw new HttpError(404, "Try-on not found");

      const job = snap.data()!;
      if (job.status === "success" || job.status === "error") {
        send(res, 200, {
          status: job.status,
          resultUrl: job.resultUrl,
          error: job.errorCode,
          jobId,
        });
        return;
      }

      const result = await getClothV4Task(job.providerTaskId as string);
      const status = result.data.task_status;

      if (status === "success") {
        const remoteUrl = result.data.results?.url;
        if (!remoteUrl) throw new HttpError(502, "YouCam finished without an image");

        let resultUrl = remoteUrl;
        let resultPath: string | null = null;
        try {
          const persisted = await persistRemoteImage({
            userId: decoded.uid,
            remoteUrl,
            folder: "tryon-results",
          });
          resultUrl = persisted.url;
          resultPath = persisted.path;
        } catch (persistError) {
          console.warn("Persist failed, keeping temporary URL", persistError);
        }

        await jobRef.update({
          status: "success",
          resultUrl,
          resultPath,
          updatedAt: Date.now(),
          completedAt: Date.now(),
        });
        send(res, 200, { status: "success", resultUrl, jobId });
        return;
      }

      if (status === "error") {
        const code = result.data.error || "unknown_error";
        await jobRef.update({
          status: "error",
          errorCode: code,
          errorMessage: code,
          updatedAt: Date.now(),
          completedAt: Date.now(),
        });
        send(res, 200, { status: "error", error: code, jobId });
        return;
      }

      send(res, 200, { status: "processing", jobId });
    } catch (error) {
      fail(res, error);
    }
  },
);

/** Gemini looks at a freshly uploaded closet photo and fills in name, category, colour and tags. */
export const tagGarment = onRequest(
  { cors: true, invoker: "public", timeoutSeconds: 60, memory: "512MiB", secrets: [geminiApiKey] },
  async (req, res) => {
    try {
      if (req.method !== "POST") throw new HttpError(405, "POST only");
      const decoded = await requireUser(req);
      const body = (req.body || {}) as { itemId?: string };
      if (!body.itemId) throw new HttpError(400, "itemId required");

      const itemRef = userDoc(decoded.uid).collection("wardrobeItems").doc(body.itemId);
      const item = (await itemRef.get()).data() as { imagePath?: string } | undefined;
      if (!item?.imagePath) throw new HttpError(404, "Closet piece not found");
      assertOwnedPath(decoded.uid, item.imagePath);

      try {
        const file = await downloadStorageFile(item.imagePath);
        const raw = await geminiGenerateFromImage({
          prompt: `You are tagging one clothing item photo for a personal wardrobe app.
Return JSON: {"name": short friendly name like "Cream cable-knit jumper" (max 5 words),
"category": one of ${JSON.stringify(WARDROBE_CATEGORIES)},
"colour": main colour in plain English (one or two words),
"pattern": "solid" | "striped" | "checked" | "floral" | "printed" | other short word,
"seasons": array from ["spring","summer","autumn","winter"],
"occasions": array from ["work","casual","date","formal","sport","travel"]}.
If the photo shows a person wearing several items, describe the most prominent garment.`,
          imageBase64: file.buffer.toString("base64"),
          mimeType: file.contentType,
        });

        const tags = extractJson<{
          name?: string;
          category?: string;
          colour?: string;
          pattern?: string;
          seasons?: string[];
          occasions?: string[];
        }>(raw);

        const update = {
          name: (tags.name || "New piece").slice(0, 60),
          category: WARDROBE_CATEGORIES.includes(tags.category || "") ? tags.category : "tops",
          colour: (tags.colour || "unknown").toLowerCase().slice(0, 30),
          pattern: tags.pattern || null,
          seasonTags: Array.isArray(tags.seasons) ? tags.seasons.slice(0, 4) : [],
          occasionTags: Array.isArray(tags.occasions) ? tags.occasions.slice(0, 6) : [],
          tagging: false,
          taggedAt: Date.now(),
          updatedAt: Date.now(),
        };
        await itemRef.update(update);
        send(res, 200, { item: update });
      } catch (error) {
        await itemRef.update({ tagging: false, updatedAt: Date.now() });
        throw error;
      }
    } catch (error) {
      fail(res, error);
    }
  },
);

/** Today's looks: profile + weather + closet, ranked by Gemini. */
export const dressMeToday = onRequest(
  { cors: true, invoker: "public", timeoutSeconds: 90, secrets: [geminiApiKey, weatherstackApiKey] },
  async (req, res) => {
    try {
      if (req.method !== "POST") throw new HttpError(405, "POST only");
      const decoded = await requireUser(req);
      const body = (req.body || {}) as { occasion?: string; city?: string; day?: string };
      const userRef = userDoc(decoded.uid);
      const profile = ((await userRef.get()).data() || {}) as {
        preferredCity?: string | null;
        genderPresentation?: string | null;
        vibes?: string[];
        favouriteColours?: string[];
        styleNotes?: string | null;
      };

      const occasion = String(body.occasion || "casual");
      const city = String(body.city || profile.preferredCity || "").trim();

      let weather: WeatherSnapshot | null = null;
      let weatherNote: string | null = null;
      if (city) {
        try {
          weather = await getCachedWeather(city);
        } catch (error) {
          weatherNote = error instanceof Error ? error.message : "Weather unavailable";
        }
      }

      const wardrobeSnap = await userRef.collection("wardrobeItems").limit(80).get();
      const wardrobe = wardrobeSnap.docs.map((d) => {
        const data = d.data() as {
          name?: string;
          category?: string;
          colour?: string;
          imageUrl?: string;
          cutoutUrl?: string;
          cutoutThumbUrl?: string;
          seasonTags?: string[];
          occasionTags?: string[];
          wearCount?: number;
          lastWornAt?: number | null;
        };
        return {
          id: d.id,
          name: data.name ?? "Item",
          category: data.category ?? "unknown",
          colour: data.colour ?? "unknown",
          imageUrl: data.imageUrl ?? null,
          cutoutUrl: data.cutoutUrl ?? null,
          cutoutThumbUrl: data.cutoutThumbUrl ?? null,
          seasons: data.seasonTags ?? [],
          occasions: data.occasionTags ?? [],
          timesWorn: data.wearCount ?? 0,
          daysSinceWorn: data.lastWornAt
            ? Math.floor((Date.now() - data.lastWornAt) / 86_400_000)
            : null,
        };
      });

      if (wardrobe.length < 2) {
        send(res, 200, {
          weather,
          weatherNote,
          suggestions: [],
          note: "Add at least two pieces to your closet and I’ll start putting outfits together.",
        });
        return;
      }

      // Short refs (p1, p2…) instead of Firestore ids — the model copies them back reliably.
      const refs = wardrobe.map((w, i) => ({ ref: `p${i + 1}`, ...w }));
      const byRef = new Map(refs.map((w) => [w.ref, w]));

      let looks: Array<{ title?: string; reason?: string; pieces?: string[] }> = [];
      try {
        const raw = await geminiGenerateText(`You are Vastra, a warm, practical personal stylist.
Occasion today: ${occasion}
Weather: ${weather ? JSON.stringify(weather) : "unknown"}
About the person: presentation=${profile.genderPresentation || "unspecified"}; aesthetics=${JSON.stringify(profile.vibes || [])} (style the looks in these aesthetics); loves colours=${JSON.stringify(profile.favouriteColours || [])}; notes=${profile.styleNotes || "none"}
Closet pieces: ${JSON.stringify(
          refs.map(({ ref, name, category, colour, seasons, occasions, timesWorn, daysSinceWorn }) => ({
            ref,
            name,
            category,
            colour,
            seasons,
            occasions,
            timesWorn,
            daysSinceWorn,
          })),
        )}

Return JSON {"looks": [{"title": string (max 4 words), "reason": string (one warm sentence mentioning weather or occasion), "pieces": string[] (refs like "p1", 2-4 pieces that work together)}]} with up to 3 looks.
Use only refs from the list. Prefer complete outfits (top + bottom, or a dress), add outerwear when it's cold or wet, and shoes/bags if available.
Rotate the closet: avoid pieces worn today or yesterday (daysSinceWorn 0-1) and favour pieces that are rarely worn or haven't been worn in a while. Make the looks clearly different from each other.`);
        const parsed = extractJson<{ looks?: typeof looks } | typeof looks>(raw);
        looks = Array.isArray(parsed) ? parsed : parsed.looks || [];
      } catch (error) {
        console.warn("Gemini styling failed, using fallback look", error);
      }

      const toItem = (w: (typeof refs)[number]) => ({
        id: w.id,
        name: w.name,
        category: w.category,
        colour: w.colour,
        imageUrl: w.imageUrl,
        cutoutUrl: w.cutoutUrl,
        cutoutThumbUrl: w.cutoutThumbUrl,
      });

      let suggestions = looks
        .slice(0, 3)
        .map((l) => {
          const pieces = [...new Set((l.pieces || []).map((p) => String(p).trim().toLowerCase()))]
            .map((p) => byRef.get(p))
            .filter((w): w is (typeof refs)[number] => Boolean(w));
          return {
            title: l.title || "Today’s look",
            reason: l.reason || "",
            wardrobeItemIds: pieces.map((w) => w.id),
            items: pieces.map(toItem),
          };
        })
        .filter((s) => s.items.length > 0);

      if (suggestions.length === 0) {
        // Always give the user something to wear: build one outfit from categories.
        const freshFirst = [...refs].sort((a, b) => (b.daysSinceWorn ?? 999) - (a.daysSinceWorn ?? 999));
        const pick = (cats: string[]) => freshFirst.find((w) => cats.includes(w.category));
        const base = pick(["dresses"]) ? [pick(["dresses"])] : [pick(["tops"]), pick(["trousers", "skirts"])];
        const cold = weather ? weather.temperatureC < 14 || weather.precipMm > 0 : false;
        const extras = [cold ? pick(["outerwear"]) : undefined, pick(["shoes"]), pick(["bags", "accessories"])];
        let chosen = [...base, ...extras].filter((w): w is (typeof refs)[number] => Boolean(w));
        if (chosen.length < 2) chosen = freshFirst.slice(0, Math.min(3, freshFirst.length));
        suggestions = [
          {
            title: "Easy everyday",
            reason: weather
              ? `A simple, comfy pick for ${Math.round(weather.temperatureC)}° and ${weather.description.toLowerCase()}.`
              : "A simple, comfy pick from your favourites.",
            wardrobeItemIds: chosen.map((w) => w.id),
            items: chosen.map(toItem),
          },
        ];
      }

      // Saved per (user's local) day + occasion so the app can open Today instantly next time.
      if (/^\d{4}-\d{2}-\d{2}$/.test(body.day || "")) {
        await userRef
          .collection("dailyLooks")
          .doc(`${body.day}_${occasion}`)
          .set({ day: body.day, occasion, weather, weatherNote, suggestions, createdAt: Date.now() });
      }
      send(res, 200, { weather, weatherNote, suggestions, wardrobeCount: wardrobe.length });
    } catch (error) {
      fail(res, error);
    }
  },
);

/**
 * "Recreate a look": Gemini reads an outfit photo, breaks it into pieces and
 * matches each one to the closest item in the user's closet.
 * Body: { imagePath, imageUrl }. Saves the result under users/{uid}/inspirations.
 */
export const recreateLook = onRequest(
  { cors: true, invoker: "public", timeoutSeconds: 90, memory: "512MiB", secrets: [geminiApiKey] },
  async (req, res) => {
    try {
      if (req.method !== "POST") throw new HttpError(405, "POST only");
      const decoded = await requireUser(req);
      const uid = decoded.uid;
      const body = (req.body || {}) as { imagePath?: string; imageUrl?: string };
      if (!body.imagePath) throw new HttpError(400, "imagePath required");
      assertOwnedPath(uid, body.imagePath);

      const userRef = userDoc(uid);
      const [file, wardrobeSnap, profileSnap] = await Promise.all([
        downloadStorageFile(body.imagePath),
        userRef.collection("wardrobeItems").limit(120).get(),
        userRef.get(),
      ]);
      const profile = (profileSnap.data() || {}) as { vibes?: string[]; genderPresentation?: string };

      const closet = wardrobeSnap.docs.map((d, i) => {
        const data = d.data() as {
          name?: string;
          category?: string;
          colour?: string;
          pattern?: string | null;
          imageUrl?: string;
          cutoutUrl?: string;
          cutoutThumbUrl?: string;
          wearCount?: number;
        };
        return {
          ref: `p${i + 1}`,
          id: d.id,
          name: data.name ?? "Item",
          category: data.category ?? "unknown",
          colour: data.colour ?? "",
          pattern: data.pattern ?? null,
          imageUrl: data.imageUrl ?? null,
          cutoutUrl: data.cutoutUrl ?? null,
          cutoutThumbUrl: data.cutoutThumbUrl ?? null,
        };
      });
      const byRef = new Map(closet.map((c) => [c.ref, c]));

      const raw = await geminiGenerateFromImage({
        prompt: `You are Pip, Vastra's warm, cheeky stylist (a little safety pin who holds outfits together).
Study the outfit in this photo and help the user recreate it from their own closet.
Their aesthetics: ${JSON.stringify(profile.vibes || [])}; presentation: ${profile.genderPresentation || "unspecified"}.
Their closet (use ONLY these refs): ${JSON.stringify(
          closet.map(({ ref, name, category, colour, pattern }) => ({ ref, name, category, colour, pattern })),
        )}

Return JSON:
{"title": short name for the look (max 4 words),
 "vibe": the look's aesthetic in 1-3 words,
 "summary": one warm sentence in Pip's voice about how close they can get,
 "score": integer 0-100 for how closely their closet recreates the look,
 "pieces": [{"piece": short description of the garment in the photo,
             "category": one of ${JSON.stringify(WARDROBE_CATEGORIES)},
             "match": a closet ref like "p3" or null,
             "closeness": "exact" | "close" | "swap" | "missing",
             "note": one short sentence — why the match works, how to style it, or what to look for}],
 "tip": one short styling tip to finish the look}
Rules: list the main visible pieces (max 6). Use each closet ref at most once.
"exact" = same garment type and colour; "close" = same type, similar colour or style;
"swap" = a different item that gives a similar effect; "missing" = nothing in the closet works (match null).`,
        imageBase64: file.buffer.toString("base64"),
        mimeType: file.contentType,
      });

      type RawPiece = { piece?: string; category?: string; match?: string | null; closeness?: string; note?: string };
      const parsed = extractJson<{
        title?: string;
        vibe?: string;
        summary?: string;
        score?: number;
        pieces?: RawPiece[];
        tip?: string;
      }>(raw);

      const used = new Set<string>();
      const pieces = (parsed.pieces || []).slice(0, 6).map((p) => {
        const ref = String(p.match || "").trim().toLowerCase();
        const item = ref && !used.has(ref) ? byRef.get(ref) : undefined;
        if (item) used.add(ref);
        const closeness = item
          ? ["exact", "close", "swap"].includes(p.closeness || "") ? p.closeness : "close"
          : "missing";
        return {
          piece: (p.piece || "Piece").slice(0, 80),
          category: WARDROBE_CATEGORIES.includes(p.category || "") ? p.category : "accessories",
          closeness,
          note: (p.note || "").slice(0, 200),
          item: item
            ? {
                id: item.id,
                name: item.name,
                category: item.category,
                colour: item.colour,
                imageUrl: item.imageUrl,
                cutoutUrl: item.cutoutUrl,
                cutoutThumbUrl: item.cutoutThumbUrl,
              }
            : null,
        };
      });

      const result = {
        kind: "recreate",
        imagePath: body.imagePath,
        imageUrl: body.imageUrl || null,
        title: (parsed.title || "Your look").slice(0, 60),
        vibe: (parsed.vibe || "").slice(0, 40),
        summary: (parsed.summary || "").slice(0, 240),
        tip: (parsed.tip || "").slice(0, 240),
        score: Math.max(0, Math.min(100, Math.round(Number(parsed.score) || 0))),
        pieces,
        createdAt: Date.now(),
      };
      const doc = await userRef.collection("inspirations").add(result);
      send(res, 200, { id: doc.id, ...result });
    } catch (error) {
      fail(res, error);
    }
  },
);

/**
 * Removes the background from a closet photo ({ itemId }) or the try-on portrait ({ portrait: true })
 * with YouCam, so pieces and people sit cleanly on Vastra's stage and tiles.
 */
export const cutoutImage = onRequest(
  { cors: true, invoker: "public", timeoutSeconds: 120, memory: "512MiB", secrets: [youcamApiKey] },
  async (req, res) => {
    try {
      if (req.method !== "POST") throw new HttpError(405, "POST only");
      const { uid } = await requireUser(req);
      const body = (req.body || {}) as { itemId?: string; portrait?: boolean };
      const userRef = userDoc(uid);

      if (body.itemId) {
        const itemRef = userRef.collection("wardrobeItems").doc(body.itemId);
        const item = (await itemRef.get()).data() as ClosetDoc | undefined;
        if (!item?.imagePath) throw new HttpError(404, "Closet piece not found");
        const current = item.cutoutUrl && item.cutoutFor === item.imagePath;
        if (current && isOptimised(item.cutoutPath) && item.cutoutThumbUrl) {
          send(res, 200, { cutoutUrl: item.cutoutUrl });
          return;
        }
        await itemRef.update({ cutoutStatus: "processing" });
        try {
          const saved =
            current && item.cutoutPath
              ? await reoptimiseCutout(uid, item.cutoutPath)
              : await cutout(uid, await youcamItemFile(uid, itemRef, item));
          await Promise.all([deleteStorageQuietly(item.cutoutPath), deleteStorageQuietly(item.cutoutThumbPath)]);
          await itemRef.update({
            cutoutUrl: saved.url,
            cutoutPath: saved.path,
            cutoutThumbUrl: saved.thumbUrl,
            cutoutThumbPath: saved.thumbPath,
            cutoutFor: item.imagePath,
            cutoutStatus: "done",
          });
          send(res, 200, { cutoutUrl: saved.url });
        } catch (error) {
          await itemRef.update({ cutoutStatus: "failed" });
          throw error;
        }
        return;
      }

      if (body.portrait) {
        const user = ((await userRef.get()).data() || {}) as ProfileDoc & {
          tryOnCutoutUrl?: string;
          tryOnCutoutPath?: string;
          tryOnCutoutFor?: string;
        };
        if (!user.tryOnPhotoPath) throw new HttpError(400, "Add your try-on portrait first");
        const current = user.tryOnCutoutUrl && user.tryOnCutoutFor === user.tryOnPhotoPath;
        if (current && isOptimised(user.tryOnCutoutPath)) {
          send(res, 200, { cutoutUrl: user.tryOnCutoutUrl });
          return;
        }
        const saved =
          current && user.tryOnCutoutPath
            ? await reoptimiseCutout(uid, user.tryOnCutoutPath)
            : await cutout(uid, await youcamPortraitFile(uid, user));
        await deleteStorageQuietly(user.tryOnCutoutPath);
        await deleteStorageQuietly(saved.thumbPath);
        await userRef.set(
          { tryOnCutoutUrl: saved.url, tryOnCutoutPath: saved.path, tryOnCutoutFor: user.tryOnPhotoPath },
          { merge: true },
        );
        send(res, 200, { cutoutUrl: saved.url });
        return;
      }

      throw new HttpError(400, "itemId or portrait required");
    } catch (error) {
      fail(res, error);
    }
  },
);

/** Order pieces go on: base layer first, then top, layer and shoes. */
const DRESS_UP_STEPS: Record<string, { garment: GarmentCategory; order: number; slot: string }> = {
  dresses: { garment: "full_body", order: 0, slot: "base" },
  trousers: { garment: "lower_body", order: 1, slot: "bottom" },
  skirts: { garment: "lower_body", order: 1, slot: "bottom" },
  tops: { garment: "upper_body", order: 2, slot: "top" },
  outerwear: { garment: "outer", order: 3, slot: "outer" },
  shoes: { garment: "shoes", order: 4, slot: "shoes" },
};

/**
 * Dress up: puts a mix-and-match outfit (top + bottoms + layer + shoes, or a dress) on the user's
 * portrait by chaining YouCam try-ons, then cuts the result out for the stage.
 * Body: { itemIds, title? }. Progress is written to the tryOnJobs doc as it goes.
 */
export const dressUp = onRequest(
  { cors: true, invoker: "public", timeoutSeconds: 540, memory: "512MiB", secrets: [youcamApiKey] },
  async (req, res) => {
    try {
      if (req.method !== "POST") throw new HttpError(405, "POST only");
      const { uid } = await requireUser(req);
      const body = (req.body || {}) as { itemIds?: string[]; title?: string };
      const ids = [...new Set((body.itemIds || []).map(String))].slice(0, 6);
      if (!ids.length) throw new HttpError(400, "Pick at least one piece");

      const userRef = userDoc(uid);
      const user = ((await userRef.get()).data() || {}) as ProfileDoc;
      if (!user.tryOnPhotoPath) throw new HttpError(400, "Add your try-on portrait first");

      const snaps = await Promise.all(ids.map((id) => userRef.collection("wardrobeItems").doc(id).get()));
      const bySlot = new Map<string, { ref: FirebaseFirestore.DocumentReference; item: ClosetDoc; id: string }>();
      for (const snap of snaps) {
        const item = snap.data() as ClosetDoc | undefined;
        const step = item && DRESS_UP_STEPS[item.category || ""];
        if (item?.imagePath && step) bySlot.set(step.slot, { ref: snap.ref, item, id: snap.id });
      }
      if (bySlot.has("base")) {
        bySlot.delete("top");
        bySlot.delete("bottom");
      }
      const pieces = [...bySlot.values()].sort(
        (a, b) => DRESS_UP_STEPS[a.item.category!].order - DRESS_UP_STEPS[b.item.category!].order,
      );
      if (!pieces.length) throw new HttpError(400, "Pick a top, bottoms, dress, layer or shoes");

      const comboKey = `${user.tryOnPhotoPath}|${pieces.map((p) => p.id).sort().join(",")}`;
      const jobs = userRef.collection("tryOnJobs");
      const cached = await jobs.where("comboKey", "==", comboKey).where("status", "==", "success").limit(1).get();
      if (!cached.empty) {
        const job = cached.docs[0].data();
        send(res, 200, {
          jobId: cached.docs[0].id,
          resultUrl: job.resultUrl,
          cutoutUrl: job.resultCutoutUrl ?? null,
          cached: true,
        });
        return;
      }

      const jobRef = jobs.doc();
      const now = Date.now();
      const first = pieces[0].item;
      await jobRef.set({
        id: jobRef.id,
        userId: uid,
        kind: "outfit",
        title: (body.title || pieces.map((p) => p.item.name || "Piece").join(" + ")).slice(0, 80),
        wardrobeItemIds: pieces.map((p) => p.id),
        wardrobeItemId: pieces.length === 1 ? pieces[0].id : null,
        comboKey,
        garmentCategory: pieces.length === 1 ? DRESS_UP_STEPS[first.category!].garment : "full_body",
        garmentImageUrl: first.cutoutUrl || first.imageUrl || null,
        status: "processing",
        step: 0,
        steps: pieces.length,
        stepLabel: null,
        resultPath: null,
        resultUrl: null,
        resultCutoutUrl: null,
        errorCode: null,
        errorMessage: null,
        unitsSpent: 0,
        createdAt: now,
        updatedAt: now,
        completedAt: null,
        createdAtServer: FieldValue.serverTimestamp(),
      });

      try {
        let srcFileId = await youcamPortraitFile(uid, user);
        let latest: { buffer: Buffer; contentType: string } | null = null;
        for (let i = 0; i < pieces.length; i++) {
          const { ref, item } = pieces[i];
          await jobRef.update({ step: i + 1, stepLabel: item.name || "piece", updatedAt: Date.now() });
          const taskId = await createClothV4Task({
            srcFileId,
            refFileId: await youcamItemFile(uid, ref, item),
            garmentCategory: DRESS_UP_STEPS[item.category!].garment,
          });
          latest = await downloadRemoteImage(await waitForTask("cloth-v4", taskId));
          srcFileId = await uploadBufferToYouCam({ ...latest, fileName: `dressup-${i}.jpg` });
        }

        const saved = await persistImage({ userId: uid, folder: "tryon-results", ...latest! });
        let cut: { path: string; url: string } | null = null;
        try {
          cut = await cutout(uid, srcFileId);
        } catch (error) {
          console.warn("Result cutout failed", error);
        }
        await jobRef.update({
          status: "success",
          resultUrl: saved.url,
          resultPath: saved.path,
          resultCutoutUrl: cut?.url ?? null,
          resultCutoutPath: cut?.path ?? null,
          unitsSpent: pieces.length * 2 + (cut ? 1 : 0),
          updatedAt: Date.now(),
          completedAt: Date.now(),
        });
        send(res, 200, { jobId: jobRef.id, resultUrl: saved.url, cutoutUrl: cut?.url ?? null });
      } catch (error) {
        const code = error instanceof Error ? error.message : "unknown_error";
        await jobRef.update({
          status: "error",
          errorCode: code,
          errorMessage: code,
          updatedAt: Date.now(),
          completedAt: Date.now(),
        });
        throw new HttpError(502, code);
      }
    } catch (error) {
      fail(res, error);
    }
  },
);

/** Permanently deletes the caller's photos, data and account. */
export const deleteAccount = onRequest(
  { cors: true, invoker: "public", timeoutSeconds: 120 },
  async (req, res) => {
    try {
      if (req.method !== "POST") throw new HttpError(405, "POST only");
      const decoded = await requireUser(req);
      const uid = decoded.uid;
      await getStorage().bucket().deleteFiles({ prefix: `users/${uid}/` });
      await getFirestore().recursiveDelete(userDoc(uid));
      await getAuth().deleteUser(uid);
      send(res, 200, { ok: true });
    } catch (error) {
      fail(res, error);
    }
  },
);

/** Web app: break an inspiration photo into clothing components. */
export const analyzeInspiration = onRequest(
  { cors: true, invoker: "public", timeoutSeconds: 90, secrets: [geminiApiKey] },
  async (req, res) => {
    try {
      if (req.method !== "POST") throw new HttpError(405, "POST only");
      await requireUser(req);
      const body = (req.body || {}) as { imageBase64?: string; mimeType?: string; imageUrl?: string };

      let base64 = body.imageBase64;
      let mimeType = body.mimeType || "image/jpeg";
      if (!base64 && body.imageUrl) {
        const imgRes = await fetch(body.imageUrl);
        if (!imgRes.ok) throw new HttpError(400, "Could not download inspiration image");
        mimeType = imgRes.headers.get("content-type") || mimeType;
        base64 = Buffer.from(await imgRes.arrayBuffer()).toString("base64");
      }
      if (!base64) throw new HttpError(400, "imageBase64 or imageUrl required");

      const raw = await geminiGenerateFromImage({
        prompt: `Identify visible clothing components in this fashion inspiration photo.
Return JSON {"components": [{"category": one of ${JSON.stringify([...WARDROBE_CATEGORIES, "unknown"])}, "colour": string, "pattern": string|null, "styleDescription": string, "confidence": number 0-1}]} with at most 6 items.`,
        imageBase64: base64,
        mimeType,
      });
      const parsed = extractJson<{ components?: unknown[] } | unknown[]>(raw);
      send(res, 200, { components: Array.isArray(parsed) ? parsed : parsed.components || [] });
    } catch (error) {
      fail(res, error);
    }
  },
);
