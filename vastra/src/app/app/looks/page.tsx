"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { useAuth } from "@/lib/auth/AuthProvider";
import { subscribeLooks } from "@/lib/data/looks";
import type { SavedLook } from "@/types/domain";

export default function LooksPage() {
  const { user } = useAuth();
  const [looks, setLooks] = useState<SavedLook[]>([]);

  useEffect(() => {
    if (!user) return;
    return subscribeLooks(user.uid, setLooks);
  }, [user]);

  return (
    <div className="space-y-8">
      <div className="fade-up">
        <span className="pill">Synced saved looks</span>
        <h1 className="mt-3 font-display text-4xl">Saved Looks</h1>
        <p className="mt-2 text-muted">
          Successful try-ons and favourites, kept with your account.
        </p>
      </div>

      {looks.length === 0 ? (
        <EmptyState
          emoji="♥"
          title="Nothing saved yet"
          description="Run a YouCam try-on and tap Save look — it’ll appear here instantly."
          action={
            <Link href="/app/try-on">
              <Button>Go to try-on</Button>
            </Link>
          }
        />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {looks.map((look) => (
            <article key={look.id} className="item-card surface overflow-hidden">
              {look.resultUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={look.resultUrl}
                  alt={look.name}
                  className="aspect-[3/4] w-full object-cover"
                />
              ) : (
                <div className="aspect-[3/4] bg-ivory-deep" />
              )}
              <div className="p-4">
                <p className="font-medium">{look.name}</p>
                <p className="text-xs text-muted">
                  {new Date(look.createdAt).toLocaleString()}
                </p>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
