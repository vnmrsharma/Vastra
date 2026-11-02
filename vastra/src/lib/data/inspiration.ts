import {
  addDoc,
  collection,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  type Unsubscribe,
} from "firebase/firestore";
import {
  getDownloadURL,
  ref,
  uploadBytes,
} from "firebase/storage";
import { getFirebaseDb, getFirebaseStorage } from "@/lib/firebase/client";
import type { Inspiration, InspirationComponent } from "@/types/domain";

function inspirationsCol(userId: string) {
  return collection(getFirebaseDb(), "users", userId, "inspirations");
}

export function subscribeInspirations(
  userId: string,
  onData: (items: Inspiration[]) => void,
): Unsubscribe {
  const q = query(inspirationsCol(userId), orderBy("createdAt", "desc"));
  return onSnapshot(q, (snap) => {
    onData(
      snap.docs.map((d) => ({
        id: d.id,
        ...(d.data() as Omit<Inspiration, "id">),
      })),
    );
  });
}

export async function uploadInspirationImage(userId: string, file: File) {
  const storage = getFirebaseStorage();
  const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
  const path = `users/${userId}/inspirations/${Date.now()}-${safeName}`;
  const storageRef = ref(storage, path);
  await uploadBytes(storageRef, file, { contentType: file.type });
  const url = await getDownloadURL(storageRef);
  return { path, url };
}

export async function createInspiration(
  userId: string,
  input: {
    imagePath: string;
    imageUrl: string;
    sourceUrl?: string | null;
    components: InspirationComponent[];
  },
) {
  const now = Date.now();
  const docRef = await addDoc(inspirationsCol(userId), {
    userId,
    imagePath: input.imagePath,
    imageUrl: input.imageUrl,
    sourceUrl: input.sourceUrl ?? null,
    components: input.components,
    analysisStatus: "ready",
    analysisError: null,
    createdAt: now,
    createdAtServer: serverTimestamp(),
  });
  return docRef.id;
}

export function fileToBase64(file: File): Promise<{ base64: string; mimeType: string }> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = String(reader.result || "");
      const base64 = result.includes(",") ? result.split(",")[1] : result;
      resolve({ base64, mimeType: file.type || "image/jpeg" });
    };
    reader.onerror = () => reject(new Error("Could not read image"));
    reader.readAsDataURL(file);
  });
}
