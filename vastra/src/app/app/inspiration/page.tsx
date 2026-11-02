"use client";

import { useEffect, useState, type FormEvent } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input } from "@/components/ui/Input";
import { useAuth } from "@/lib/auth/AuthProvider";
import { analyzeInspiration } from "@/lib/api/functions";
import {
  createInspiration,
  fileToBase64,
  subscribeInspirations,
  uploadInspirationImage,
} from "@/lib/data/inspiration";
import { listWardrobe } from "@/lib/data/wardrobe";
import type {
  Inspiration,
  InspirationComponent,
  MatchStatus,
  WardrobeCategory,
  WardrobeItem,
} from "@/types/domain";

function matchComponents(
  components: Array<{
    category: string;
    colour: string;
    pattern: string | null;
    styleDescription: string;
    confidence: number;
  }>,
  wardrobe: WardrobeItem[],
): InspirationComponent[] {
  return components.map((c, index) => {
    const category = c.category as WardrobeCategory | "unknown";
    const colour = (c.colour || "").toLowerCase();
    const candidates = wardrobe.filter((w) => {
      const catOk =
        category === "unknown" ||
        w.category === category ||
        (category === "trousers" && w.category === "skirts");
      const colourOk =
        !colour ||
        w.colour.toLowerCase().includes(colour) ||
        colour.includes(w.colour.toLowerCase());
      return catOk && colourOk;
    });

    let matchStatus: MatchStatus = "missing";
    let matchedWardrobeItemId: string | null = null;
    if (candidates.length) {
      matchStatus = "matched";
      matchedWardrobeItemId = candidates[0].id;
    } else {
      const similar = wardrobe.find(
        (w) => w.category === category || w.colour.toLowerCase().includes(colour),
      );
      if (similar) {
        matchStatus = "similar";
        matchedWardrobeItemId = similar.id;
      }
    }

    return {
      id: `c-${index}-${Date.now()}`,
      category,
      colour: c.colour,
      pattern: c.pattern,
      styleDescription: c.styleDescription,
      matchStatus,
      matchedWardrobeItemId,
      confidence: c.confidence ?? 0.5,
    };
  });
}

const statusStyles: Record<MatchStatus, string> = {
  matched: "bg-mint text-success",
  similar: "bg-blush text-burgundy",
  missing: "bg-ivory-deep text-muted",
};

export default function InspirationPage() {
  const { user } = useAuth();
  const [items, setItems] = useState<Inspiration[]>([]);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [sourceUrl, setSourceUrl] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [latestComponents, setLatestComponents] = useState<
    InspirationComponent[] | null
  >(null);

  useEffect(() => {
    if (!user) return;
    return subscribeInspirations(user.uid, setItems);
  }, [user]);

  async function onAnalyze(e: FormEvent) {
    e.preventDefault();
    if (!user || !file) {
      setError("Choose an inspiration image first.");
      return;
    }
    setBusy(true);
    setError(null);
    setLatestComponents(null);
    try {
      const uploaded = await uploadInspirationImage(user.uid, file);
      const { base64, mimeType } = await fileToBase64(file);
      const analyzed = await analyzeInspiration({
        imageBase64: base64,
        mimeType,
      });
      const wardrobe = await listWardrobe(user.uid);
      const components = matchComponents(analyzed.components || [], wardrobe);
      await createInspiration(user.uid, {
        imagePath: uploaded.path,
        imageUrl: uploaded.url,
        sourceUrl: sourceUrl.trim() || null,
        components,
      });
      setLatestComponents(components);
      setFile(null);
      setPreview(null);
      setSourceUrl("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Analysis failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-8">
      <div className="fade-up">
        <span className="pill">Gemini vision · closet match</span>
        <h1 className="mt-3 font-display text-4xl">Inspiration Studio</h1>
        <p className="mt-2 max-w-2xl text-muted">
          Drop a screenshot of a look you love. We’ll spot the pieces and check
          what you already own.
        </p>
      </div>

      <form onSubmit={onAnalyze} className="surface fade-up-delay space-y-4 p-5">
        <label className="block space-y-1.5 text-sm">
          <span>Inspiration photo</span>
          <input
            type="file"
            accept="image/*"
            onChange={(e) => {
              const f = e.target.files?.[0] ?? null;
              setFile(f);
              setPreview(f ? URL.createObjectURL(f) : null);
            }}
          />
        </label>
        {preview && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={preview}
            alt="Inspiration preview"
            className="max-h-64 rounded-2xl object-contain bg-ivory"
          />
        )}
        <label className="block space-y-1.5 text-sm">
          <span>Source URL (optional)</span>
          <Input
            value={sourceUrl}
            onChange={(e) => setSourceUrl(e.target.value)}
            placeholder="https://…"
          />
        </label>
        {error && (
          <p className="rounded-xl bg-danger/10 px-3 py-2 text-sm text-danger">
            {error}
          </p>
        )}
        <Button type="submit" disabled={busy}>
          {busy ? "Reading the look…" : "Analyze look"}
        </Button>
      </form>

      {latestComponents && (
        <section className="surface space-y-3 p-5">
          <h2 className="font-display text-2xl">Just matched</h2>
          <div className="space-y-2">
            {latestComponents.map((c) => (
              <div
                key={c.id}
                className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-border bg-ivory/60 px-3 py-2"
              >
                <div>
                  <p className="text-sm font-medium capitalize">
                    {c.category} · {c.colour}
                  </p>
                  <p className="text-xs text-muted">{c.styleDescription}</p>
                </div>
                <span className={`pill ${statusStyles[c.matchStatus]}`}>
                  {c.matchStatus}
                </span>
              </div>
            ))}
          </div>
          {latestComponents.some((c) => c.matchStatus === "missing") && (
            <Link href="/app/try-on">
              <Button variant="soft">Try a missing piece</Button>
            </Link>
          )}
        </section>
      )}

      <section className="space-y-3">
        <h2 className="font-display text-3xl">Recent inspirations</h2>
        {items.length === 0 ? (
          <EmptyState
            emoji="❀"
            title="No inspirations yet"
            description="Upload a Pinterest screenshot or outfit photo to begin."
          />
        ) : (
          <div className="grid gap-4 md:grid-cols-2">
            {items.map((item) => (
              <article key={item.id} className="item-card surface overflow-hidden">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={item.imageUrl}
                  alt="Inspiration"
                  className="aspect-[4/3] w-full object-cover"
                />
                <div className="space-y-2 p-4">
                  <p className="text-xs text-muted">
                    {item.components?.length || 0} components detected
                  </p>
                  <div className="flex flex-wrap gap-1.5">
                    {(item.components || []).slice(0, 4).map((c) => (
                      <span
                        key={c.id}
                        className={`pill ${statusStyles[c.matchStatus]}`}
                      >
                        {c.category}:{c.matchStatus}
                      </span>
                    ))}
                  </div>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
