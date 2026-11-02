"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Select } from "@/components/ui/Select";
import { useAuth } from "@/lib/auth/AuthProvider";
import { subscribeWardrobe } from "@/lib/data/wardrobe";
import { OCCASIONS, type Occasion, type WardrobeItem } from "@/types/domain";

export default function HomePage() {
  const { user, profile } = useAuth();
  const [items, setItems] = useState<WardrobeItem[]>([]);
  const [occasion, setOccasion] = useState<Occasion>("casual");

  useEffect(() => {
    if (!user) return;
    return subscribeWardrobe(user.uid, setItems);
  }, [user]);

  const preview = items.slice(0, 4);
  const firstName = profile?.displayName?.split(" ")[0] || "there";

  return (
    <div className="space-y-10">
      <section className="surface relative overflow-hidden px-6 py-10 md:px-10">
        <div className="vastra-grid pointer-events-none absolute inset-0 opacity-25" />
        <div className="relative fade-up">
          <span className="pill">Synced · {items.length} pieces</span>
          <h1 className="mt-4 font-display text-4xl text-charcoal md:text-5xl">
            Hello, {firstName}
          </h1>
          <p className="mt-3 max-w-xl text-chocolate/85">
            Soft suggestions from your real closet, then YouCam try-on when
            something’s missing.
          </p>

          <div className="mt-8 flex flex-col gap-3 rounded-2xl border border-border/80 bg-ivory/80 p-4 md:flex-row md:items-end">
            <label className="flex-1 space-y-1.5 text-sm">
              <span className="text-muted">What’s the vibe today?</span>
              <Select
                value={occasion}
                onChange={(e) => setOccasion(e.target.value as Occasion)}
              >
                {OCCASIONS.map((o) => (
                  <option key={o.value} value={o.value}>
                    {o.label}
                  </option>
                ))}
              </Select>
            </label>
            <Link href={`/app/dress-me?occasion=${occasion}`}>
              <Button className="w-full md:w-auto">Dress me today</Button>
            </Link>
          </div>

          <div className="mt-5 flex flex-wrap gap-2">
            <Link href="/app/inspiration">
              <Button variant="soft">Upload inspiration</Button>
            </Link>
            <Link href="/app/closet">
              <Button variant="secondary">Open closet</Button>
            </Link>
            <Link href="/app/try-on">
              <Button variant="ghost">Virtual try-on</Button>
            </Link>
          </div>
        </div>
      </section>

      <section className="fade-up-delay">
        <div className="mb-4 flex items-end justify-between">
          <div>
            <h2 className="font-display text-3xl">Your closet</h2>
            <p className="text-sm text-muted">Live updates as you add pieces</p>
          </div>
          <Link href="/app/closet" className="text-sm text-burgundy">
            View all
          </Link>
        </div>

        {preview.length === 0 ? (
          <EmptyState
            emoji="✦"
            title="Your wardrobe is waiting"
            description="Add a few favourites and Vastra can start dressing you for real days."
            action={
              <Link href="/app/closet">
                <Button>Add first item</Button>
              </Link>
            }
          />
        ) : (
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            {preview.map((item) => (
              <article key={item.id} className="item-card surface overflow-hidden">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={item.imageUrl}
                  alt={item.name}
                  className="aspect-[3/4] w-full object-cover"
                />
                <div className="p-3">
                  <p className="truncate text-sm font-medium">{item.name}</p>
                  <p className="text-xs capitalize text-muted">
                    {item.category} · {item.colour}
                  </p>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>

      {!profile?.tryOnPhotoUrl && (
        <section className="rounded-2xl border border-burgundy/15 bg-blush/40 px-5 py-4 text-sm">
          <p className="font-medium text-burgundy">One photo unlocks try-on magic</p>
          <p className="mt-1 text-muted">
            Full body, facing forward, soft light — then YouCam can dress you.
          </p>
          <Link href="/app/onboarding" className="mt-3 inline-block">
            <Button variant="secondary">Add photo</Button>
          </Link>
        </section>
      )}
    </div>
  );
}
