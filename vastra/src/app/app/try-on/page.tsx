"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/Button";
import { Select } from "@/components/ui/Select";
import { useAuth } from "@/lib/auth/AuthProvider";
import { pollTryOnUntilDone, startTryOn } from "@/lib/api/functions";
import { saveLook } from "@/lib/data/looks";
import { subscribeWardrobe, uploadWardrobeImage } from "@/lib/data/wardrobe";
import {
  GARMENT_CATEGORIES,
  type GarmentCategory,
  type WardrobeItem,
} from "@/types/domain";

type Phase = "idle" | "starting" | "processing" | "success" | "error";

export default function TryOnPage() {
  const { user, profile } = useAuth();
  const [items, setItems] = useState<WardrobeItem[]>([]);
  const [garmentCategory, setGarmentCategory] =
    useState<GarmentCategory>("full_body");
  const [selectedItemId, setSelectedItemId] = useState<string>("");
  const [garmentFile, setGarmentFile] = useState<File | null>(null);
  const [garmentPreview, setGarmentPreview] = useState<string | null>(null);
  const [phase, setPhase] = useState<Phase>("idle");
  const [statusNote, setStatusNote] = useState("");
  const [resultUrl, setResultUrl] = useState<string | null>(null);
  const [jobId, setJobId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (!user) return;
    return subscribeWardrobe(user.uid, setItems);
  }, [user]);

  const selectedItem = items.find((i) => i.id === selectedItemId) ?? null;

  function onGarmentFile(file: File | null) {
    setGarmentFile(file);
    setGarmentPreview(file ? URL.createObjectURL(file) : null);
    if (file) setSelectedItemId("");
  }

  async function resolveGarmentUrl() {
    if (selectedItem?.imageUrl) return selectedItem.imageUrl;
    if (garmentFile && user) {
      const uploaded = await uploadWardrobeImage(user.uid, garmentFile);
      return uploaded.url;
    }
    throw new Error("Choose a closet piece or upload a garment photo.");
  }

  async function onGenerate() {
    if (!user) return;
    if (!profile?.tryOnPhotoUrl) {
      setError("Add your try-on photo in setup first.");
      return;
    }

    setError(null);
    setSaved(false);
    setResultUrl(null);
    setPhase("starting");
    setStatusNote("Sending photos to YouCam…");

    try {
      const garmentImageUrl = await resolveGarmentUrl();
      const started = await startTryOn({
        personImageUrl: profile.tryOnPhotoUrl,
        garmentImageUrl,
        garmentCategory,
        wardrobeItemId: selectedItem?.id ?? null,
      });
      setJobId(started.jobId);
      setPhase("processing");
      setStatusNote("YouCam is styling you — hang tight…");

      const done = await pollTryOnUntilDone(started.jobId, {
        onTick: (s) => {
          if (s === "processing") {
            setStatusNote("Still rendering your look…");
          }
        },
      });

      if (done.status === "success" && done.resultUrl) {
        setResultUrl(done.resultUrl);
        setPhase("success");
        setStatusNote("Ready — here’s your try-on.");
      } else {
        setPhase("error");
        setError(done.error || "YouCam could not complete this try-on.");
        setStatusNote("");
      }
    } catch (err) {
      setPhase("error");
      setError(err instanceof Error ? err.message : "Try-on failed");
      setStatusNote("");
    }
  }

  async function onSave() {
    if (!user || !resultUrl) return;
    await saveLook(user.uid, {
      name: selectedItem?.name
        ? `Try-on · ${selectedItem.name}`
        : `Try-on · ${garmentCategory}`,
      tryOnJobId: jobId,
      resultUrl,
    });
    setSaved(true);
  }

  const busy = phase === "starting" || phase === "processing";

  return (
    <div className="space-y-8">
      <div className="fade-up">
        <span className="pill">YouCam · cloth-v4</span>
        <h1 className="mt-3 font-display text-4xl">Virtual Try-On</h1>
        <p className="mt-2 max-w-2xl text-muted">
          Real Perfect Corp try-on. Full body works best with a complete outfit
          reference. Results sync to your account.
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="surface fade-up space-y-4 p-5">
          <h2 className="font-display text-2xl">You</h2>
          {profile?.tryOnPhotoUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={profile.tryOnPhotoUrl}
              alt="Your try-on photo"
              className="max-h-80 w-full rounded-2xl object-contain bg-ivory"
            />
          ) : (
            <div className="rounded-2xl bg-ivory px-4 py-12 text-center text-sm text-muted">
              No try-on photo yet.{" "}
              <Link href="/app/onboarding" className="text-burgundy underline">
                Add one
              </Link>
            </div>
          )}
        </section>

        <section className="surface fade-up-delay space-y-4 p-5">
          <h2 className="font-display text-2xl">Garment</h2>

          <label className="block space-y-1.5 text-sm">
            <span>Category</span>
            <Select
              value={garmentCategory}
              onChange={(e) =>
                setGarmentCategory(e.target.value as GarmentCategory)
              }
            >
              {GARMENT_CATEGORIES.map((g) => (
                <option key={g.value} value={g.value}>
                  {g.label}
                </option>
              ))}
            </Select>
          </label>

          <label className="block space-y-1.5 text-sm">
            <span>From your closet</span>
            <Select
              value={selectedItemId}
              onChange={(e) => {
                setSelectedItemId(e.target.value);
                if (e.target.value) {
                  setGarmentFile(null);
                  setGarmentPreview(null);
                }
              }}
            >
              <option value="">Select a piece…</option>
              {items.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name} ({item.category})
                </option>
              ))}
            </Select>
          </label>

          <div className="text-center text-xs uppercase tracking-[0.2em] text-muted">
            or upload
          </div>

          <input
            type="file"
            accept="image/jpeg,image/png,image/jpg,image/webp"
            onChange={(e) => onGarmentFile(e.target.files?.[0] ?? null)}
          />

          {(garmentPreview || selectedItem?.imageUrl) && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={garmentPreview || selectedItem?.imageUrl || ""}
              alt="Garment"
              className="max-h-48 rounded-xl object-contain bg-ivory"
            />
          )}

          <Button
            className="w-full"
            disabled={busy || !profile?.tryOnPhotoUrl}
            onClick={onGenerate}
          >
            {busy ? "Working with YouCam…" : "Generate try-on"}
          </Button>

          {statusNote && (
            <p className="rounded-xl bg-mint/70 px-3 py-2 text-sm text-success">
              {statusNote}
            </p>
          )}
          {error && (
            <p className="rounded-xl bg-danger/10 px-3 py-2 text-sm text-danger">
              {error}
            </p>
          )}
        </section>
      </div>

      {phase === "processing" && (
        <div className="surface p-6">
          <div className="shimmer h-64 rounded-2xl" />
          <p className="mt-3 text-center text-sm text-muted">
            Rendering your look…
          </p>
        </div>
      )}

      {resultUrl && (
        <section className="surface fade-up space-y-4 p-5">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <h2 className="font-display text-2xl">Your result</h2>
            <div className="flex gap-2">
              <Button variant="secondary" onClick={onSave} disabled={saved}>
                {saved ? "Saved ♥" : "Save look"}
              </Button>
              <Link href="/app/looks">
                <Button variant="ghost">View looks</Button>
              </Link>
            </div>
          </div>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={resultUrl}
            alt="Try-on result"
            className="mx-auto max-h-[32rem] rounded-2xl object-contain"
          />
        </section>
      )}
    </div>
  );
}
