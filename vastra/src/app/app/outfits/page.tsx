import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";

export default function OutfitsPage() {
  return (
    <div className="space-y-6">
      <div>
        <span className="pill">Coming together</span>
        <h1 className="mt-3 font-display text-4xl">Outfit Studio</h1>
        <p className="mt-2 text-muted">
          For now, use Dress me today and Inspiration — full outfit editing lands
          next.
        </p>
      </div>
      <EmptyState
        emoji="◎"
        title="Start from a suggestion"
        description="Get weather-aware looks from your closet, or match an inspiration photo."
        action={
          <div className="flex flex-wrap justify-center gap-2">
            <Link href="/app/dress-me">
              <Button>Dress me</Button>
            </Link>
            <Link href="/app/inspiration">
              <Button variant="secondary">Inspiration</Button>
            </Link>
          </div>
        }
      />
    </div>
  );
}
