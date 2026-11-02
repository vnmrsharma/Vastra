import Link from "next/link";
import { Button } from "@/components/ui/Button";

export function ComingSoon({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <div className="mx-auto max-w-lg space-y-4 rounded-2xl border border-border bg-soft-white px-6 py-12 text-center">
      <h1 className="font-display text-4xl">{title}</h1>
      <p className="text-muted">{description}</p>
      <p className="text-xs uppercase tracking-[0.2em] text-burgundy">
        Wiring next · YouCam core
      </p>
      <Link href="/app">
        <Button variant="secondary">Back home</Button>
      </Link>
    </div>
  );
}
