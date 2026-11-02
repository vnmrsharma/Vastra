import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  type Unsubscribe,
  onSnapshot,
} from "firebase/firestore";
import {
  getDownloadURL,
  ref,
  uploadBytes,
  deleteObject,
} from "firebase/storage";
import { getFirebaseDb, getFirebaseStorage } from "@/lib/firebase/client";
import type { WardrobeCategory, WardrobeItem } from "@/types/domain";

function wardrobeCol(userId: string) {
  return collection(getFirebaseDb(), "users", userId, "wardrobeItems");
}

export function subscribeWardrobe(
  userId: string,
  onData: (items: WardrobeItem[]) => void,
  onError?: (error: Error) => void,
): Unsubscribe {
  const q = query(wardrobeCol(userId), orderBy("createdAt", "desc"));
  return onSnapshot(
    q,
    (snap) => {
      const items = snap.docs.map((d) => ({
        id: d.id,
        ...(d.data() as Omit<WardrobeItem, "id">),
      }));
      onData(items);
    },
    (error) => onError?.(error),
  );
}

export async function listWardrobe(userId: string): Promise<WardrobeItem[]> {
  const q = query(wardrobeCol(userId), orderBy("createdAt", "desc"));
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({
    id: d.id,
    ...(d.data() as Omit<WardrobeItem, "id">),
  }));
}

export async function uploadWardrobeImage(
  userId: string,
  file: File,
): Promise<{ path: string; url: string }> {
  const storage = getFirebaseStorage();
  const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
  const path = `users/${userId}/wardrobe/${Date.now()}-${safeName}`;
  const storageRef = ref(storage, path);
  await uploadBytes(storageRef, file, { contentType: file.type });
  const url = await getDownloadURL(storageRef);
  return { path, url };
}

export interface CreateWardrobeInput {
  name: string;
  category: WardrobeCategory;
  colour: string;
  pattern?: string | null;
  material?: string | null;
  brand?: string | null;
  size?: string | null;
  notes?: string | null;
  imagePath: string;
  imageUrl: string;
}

export async function createWardrobeItem(
  userId: string,
  input: CreateWardrobeInput,
): Promise<string> {
  const now = Date.now();
  const docRef = await addDoc(wardrobeCol(userId), {
    userId,
    name: input.name,
    category: input.category,
    colour: input.colour,
    pattern: input.pattern ?? null,
    material: input.material ?? null,
    brand: input.brand ?? null,
    size: input.size ?? null,
    seasonTags: [],
    occasionTags: [],
    notes: input.notes ?? null,
    imagePath: input.imagePath,
    imageUrl: input.imageUrl,
    cutoutPath: null,
    cutoutUrl: null,
    youcamFileId: null,
    createdAt: now,
    updatedAt: now,
    createdAtServer: serverTimestamp(),
    updatedAtServer: serverTimestamp(),
  });
  return docRef.id;
}

export async function updateWardrobeItem(
  userId: string,
  itemId: string,
  patch: Partial<
    Pick<
      WardrobeItem,
      | "name"
      | "category"
      | "colour"
      | "pattern"
      | "material"
      | "brand"
      | "size"
      | "notes"
      | "seasonTags"
      | "occasionTags"
    >
  >,
) {
  await updateDoc(doc(getFirebaseDb(), "users", userId, "wardrobeItems", itemId), {
    ...patch,
    updatedAt: Date.now(),
    updatedAtServer: serverTimestamp(),
  });
}

export async function deleteWardrobeItem(userId: string, item: WardrobeItem) {
  await deleteDoc(
    doc(getFirebaseDb(), "users", userId, "wardrobeItems", item.id),
  );
  try {
    if (item.imagePath) {
      await deleteObject(ref(getFirebaseStorage(), item.imagePath));
    }
  } catch {
    // Image may already be gone
  }
}
