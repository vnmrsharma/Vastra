import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";

export default function MissingPage() {
  return (
    <div className="space-y-6">
      <div>
        <span className="pill">Gaps → try-on</span>
        <h1 className="mt-3 font-display text-4xl">Missing Pieces</h1>
        <p className="mt-2 text-muted">
          Spot gaps in Inspiration Studio, then virtually try candidates with
          YouCam.
        </p>
      </div>
      <EmptyState
        emoji="＋"
        title="Find what’s missing"
        description="Analyze a look, see which components you don’t own, then try products on."
        action={
          <div className="flex flex-wrap justify-center gap-2">
            <Link href="/app/inspiration">
              <Button>Open inspiration</Button>
            </Link>
            <Link href="/app/try-on">
              <Button variant="secondary">Try-on</Button>
            </Link>
          </div>
        }
      />
    </div>
  );
}
