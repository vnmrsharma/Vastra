import { getStorage } from "firebase-admin/storage";

export function assertOwnedPath(uid: string, path: string) {
  if (!path.startsWith(`users/${uid}/`) || path.includes("..")) {
    const err = new Error("That file doesn't belong to this account");
    (err as Error & { status: number }).status = 403;
    throw err;
  }
}

export async function downloadStorageFile(path: string) {
  const file = getStorage().bucket().file(path);
  const [[buffer], [metadata]] = await Promise.all([file.download(), file.getMetadata()]);
  return {
    buffer,
    contentType: String(metadata.contentType || "image/jpeg"),
    fileName: path.split("/").pop() || "image.jpg",
  };
}
