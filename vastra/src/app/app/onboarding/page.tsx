"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { useAuth } from "@/lib/auth/AuthProvider";
import { updateUserProfile, uploadTryOnPhoto } from "@/lib/data/profile";

export default function OnboardingPage() {
  const { user, profile, refreshProfile } = useAuth();
  const router = useRouter();
  const [city, setCity] = useState(profile?.preferredCity ?? "");
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(
    profile?.tryOnPhotoUrl ?? null,
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function onFile(f: File | null) {
    setFile(f);
    if (f) setPreview(URL.createObjectURL(f));
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!user) return;
    setBusy(true);
    setError(null);
    try {
      if (file) {
        await uploadTryOnPhoto(user.uid, file);
      }
      await updateUserProfile(user.uid, {
        preferredCity: city.trim() || null,
        onboardingComplete: true,
      });
      await refreshProfile();
      router.replace("/app");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save setup");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-xl space-y-8">
      <div className="fade-up">
        <span className="pill">Almost ready</span>
        <h1 className="mt-3 font-display text-4xl">Make try-on feel personal</h1>
        <p className="mt-2 text-muted">
          City for weather-aware outfits, and a full-body photo for YouCam.
        </p>
      </div>

      <form
        onSubmit={onSubmit}
        className="surface fade-up-delay space-y-5 p-6"
      >
        <label className="block space-y-1.5 text-sm">
          <span>Home city (for weather)</span>
          <Input
            value={city}
            onChange={(e) => setCity(e.target.value)}
            placeholder="London"
          />
        </label>

        <div className="space-y-2 text-sm">
          <span>Try-on photo</span>
          <div className="rounded-2xl border border-dashed border-border bg-ivory/60 p-4">
            {preview ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={preview}
                alt="Try-on preview"
                className="mx-auto max-h-72 rounded-xl object-contain"
              />
            ) : (
              <p className="py-10 text-center text-muted">
                Full body · facing forward · one person · soft light
              </p>
            )}
            <input
              type="file"
              accept="image/jpeg,image/png,image/jpg"
              className="mt-4 w-full text-sm"
              onChange={(e) => onFile(e.target.files?.[0] ?? null)}
            />
          </div>
        </div>

        {error && (
          <p className="rounded-xl bg-danger/10 px-3 py-2 text-sm text-danger">
            {error}
          </p>
        )}

        <div className="flex flex-wrap gap-3">
          <Button type="submit" disabled={busy}>
            {busy ? "Saving…" : "Save & continue"}
          </Button>
          <Button
            type="button"
            variant="ghost"
            onClick={() => router.replace("/app")}
          >
            Skip for now
          </Button>
        </div>
      </form>
    </div>
  );
}
