"use client";

import { useState, type FormEvent } from "react";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import {
  createWardrobeItem,
  uploadWardrobeImage,
} from "@/lib/data/wardrobe";
import { WARDROBE_CATEGORIES, type WardrobeCategory } from "@/types/domain";

export function AddItemForm({
  userId,
  onCreated,
}: {
  userId: string;
  onCreated?: () => void;
}) {
  const [name, setName] = useState("");
  const [category, setCategory] = useState<WardrobeCategory>("tops");
  const [colour, setColour] = useState("");
  const [brand, setBrand] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);

  function onFile(f: File | null) {
    setFile(f);
    setPreview(f ? URL.createObjectURL(f) : null);
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!file) {
      setError("Please choose a clothing photo.");
      return;
    }
    setBusy(true);
    setError(null);
    setOk(null);
    try {
      const uploaded = await uploadWardrobeImage(userId, file);
      await createWardrobeItem(userId, {
        name: name.trim() || "Untitled piece",
        category,
        colour: colour.trim() || "unknown",
        brand: brand.trim() || null,
        imagePath: uploaded.path,
        imageUrl: uploaded.url,
      });
      setName("");
      setColour("");
      setBrand("");
      setFile(null);
      setPreview(null);
      setOk("Saved to your closet — it’s live everywhere.");
      onCreated?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Upload failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="surface space-y-4 p-5">
      <h2 className="font-display text-2xl">Add clothing</h2>
      <div className="grid gap-4 md:grid-cols-2">
        <label className="space-y-1.5 text-sm md:col-span-2">
          <span>Photo</span>
          <input
            type="file"
            accept="image/jpeg,image/png,image/jpg,image/webp"
            required
            onChange={(e) => onFile(e.target.files?.[0] ?? null)}
          />
          {preview && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={preview}
              alt="Preview"
              className="mt-2 max-h-48 rounded-2xl object-contain bg-ivory"
            />
          )}
        </label>
        <label className="space-y-1.5 text-sm">
          <span>Name</span>
          <Input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Navy knit sweater"
          />
        </label>
        <label className="space-y-1.5 text-sm">
          <span>Category</span>
          <Select
            value={category}
            onChange={(e) => setCategory(e.target.value as WardrobeCategory)}
          >
            {WARDROBE_CATEGORIES.map((c) => (
              <option key={c.value} value={c.value}>
                {c.label}
              </option>
            ))}
          </Select>
        </label>
        <label className="space-y-1.5 text-sm">
          <span>Colour</span>
          <Input
            value={colour}
            onChange={(e) => setColour(e.target.value)}
            placeholder="Navy"
          />
        </label>
        <label className="space-y-1.5 text-sm">
          <span>Brand (optional)</span>
          <Input value={brand} onChange={(e) => setBrand(e.target.value)} />
        </label>
      </div>
      {error && (
        <p className="rounded-xl bg-danger/10 px-3 py-2 text-sm text-danger">
          {error}
        </p>
      )}
      {ok && (
        <p className="rounded-xl bg-mint/70 px-3 py-2 text-sm text-success">
          {ok}
        </p>
      )}
      <Button type="submit" disabled={busy}>
        {busy ? "Uploading…" : "Save to closet"}
      </Button>
    </form>
  );
}
