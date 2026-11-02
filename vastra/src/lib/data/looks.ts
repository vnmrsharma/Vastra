import {
  addDoc,
  collection,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  type Unsubscribe,
} from "firebase/firestore";
import { getFirebaseDb } from "@/lib/firebase/client";
import type { SavedLook } from "@/types/domain";

function looksCol(userId: string) {
  return collection(getFirebaseDb(), "users", userId, "savedLooks");
}

export function subscribeLooks(
  userId: string,
  onData: (looks: SavedLook[]) => void,
  onError?: (error: Error) => void,
): Unsubscribe {
  const q = query(looksCol(userId), orderBy("createdAt", "desc"));
  return onSnapshot(
    q,
    (snap) => {
      onData(
        snap.docs.map((d) => ({
          id: d.id,
          ...(d.data() as Omit<SavedLook, "id">),
        })),
      );
    },
    (error) => onError?.(error),
  );
}

export async function saveLook(
  userId: string,
  input: {
    name: string;
    outfitId?: string | null;
    tryOnJobId?: string | null;
    productId?: string | null;
    resultUrl?: string | null;
  },
) {
  const docRef = await addDoc(looksCol(userId), {
    userId,
    name: input.name,
    outfitId: input.outfitId ?? null,
    tryOnJobId: input.tryOnJobId ?? null,
    productId: input.productId ?? null,
    resultUrl: input.resultUrl ?? null,
    createdAt: Date.now(),
    createdAtServer: serverTimestamp(),
  });
  return docRef.id;
}
