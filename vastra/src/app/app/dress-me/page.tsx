import { Suspense } from "react";
import { DressMeClient } from "./DressMeClient";

export default function DressMePage() {
  return (
    <Suspense fallback={<p className="text-muted">Loading…</p>}>
      <DressMeClient />
    </Suspense>
  );
}
