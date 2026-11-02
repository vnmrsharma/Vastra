import { getStorage } from "firebase-admin/storage";
import { randomUUID } from "crypto";

export async function downloadRemoteImage(remoteUrl: string): Promise<{ buffer: Buffer; contentType: string }> {
  const res = await fetch(remoteUrl);
  if (!res.ok) {
    throw new Error(`Failed to download result image (${res.status})`);
  }
  return {
    buffer: Buffer.from(await res.arrayBuffer()),
    contentType: res.headers.get("content-type") || "image/jpeg",
  };
}

/** Download a remote image and store it permanently in Firebase Storage. */
export async function persistRemoteImage(input: {
  userId: string;
  remoteUrl: string;
  folder: string;
}): Promise<{ path: string; url: string }> {
  return persistImage({ userId: input.userId, folder: input.folder, ...(await downloadRemoteImage(input.remoteUrl)) });
}

/** Store image bytes permanently in Firebase Storage with a download token. */
export async function persistImage(input: {
  userId: string;
  folder: string;
  buffer: Buffer;
  contentType: string;
}): Promise<{ path: string; url: string }> {
  const { buffer, contentType } = input;
  const ext = contentType.includes("png") ? "png" : contentType.includes("webp") ? "webp" : "jpg";
  const path = `users/${input.userId}/${input.folder}/${Date.now()}-${randomUUID()}.${ext}`;
  const token = randomUUID();
  const bucket = getStorage().bucket();
  const file = bucket.file(path);

  await file.save(buffer, {
    metadata: {
      contentType,
      // Paths are unique per upload, so browsers can keep these forever.
      cacheControl: "public, max-age=31536000, immutable",
      metadata: {
        source: "youcam",
        firebaseStorageDownloadTokens: token,
      },
    },
    resumable: false,
  });

  const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(
    path,
  )}?alt=media&token=${token}`;

  return { path, url };
}
