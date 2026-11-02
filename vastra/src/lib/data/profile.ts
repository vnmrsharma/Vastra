import { doc, serverTimestamp, updateDoc } from "firebase/firestore";
import {
  getDownloadURL,
  ref,
  uploadBytes,
} from "firebase/storage";
import { getFirebaseDb, getFirebaseStorage } from "@/lib/firebase/client";
import type { UserProfile } from "@/types/domain";

export async function updateUserProfile(
  userId: string,
  patch: Partial<
    Pick<
      UserProfile,
      | "displayName"
      | "onboardingComplete"
      | "consentAiProcessing"
      | "preferredCity"
      | "styleNotes"
      | "tryOnPhotoPath"
      | "tryOnPhotoUrl"
    >
  >,
) {
  await updateDoc(doc(getFirebaseDb(), "users", userId), {
    ...patch,
    updatedAt: Date.now(),
    updatedAtServer: serverTimestamp(),
  });
}

export async function uploadTryOnPhoto(userId: string, file: File) {
  const storage = getFirebaseStorage();
  const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
  const path = `users/${userId}/tryon/person-${Date.now()}-${safeName}`;
  const storageRef = ref(storage, path);
  await uploadBytes(storageRef, file, { contentType: file.type });
  const url = await getDownloadURL(storageRef);
  await updateUserProfile(userId, {
    tryOnPhotoPath: path,
    tryOnPhotoUrl: url,
  });
  return { path, url };
}
