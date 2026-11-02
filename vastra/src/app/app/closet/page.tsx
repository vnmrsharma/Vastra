"use client";

import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Select } from "@/components/ui/Select";
import { AddItemForm } from "@/components/closet/AddItemForm";
import { useAuth } from "@/lib/auth/AuthProvider";
import { deleteWardrobeItem, subscribeWardrobe } from "@/lib/data/wardrobe";
import {
  WARDROBE_CATEGORIES,
  type WardrobeCategory,
  type WardrobeItem,
} from "@/types/domain";

export default function ClosetPage() {
  const { user } = useAuth();
  const [items, setItems] = useState<WardrobeItem[]>([]);
  const [filter, setFilter] = useState<WardrobeCategory | "all">("all");
  const [showAdd, setShowAdd] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    return subscribeWardrobe(user.uid, setItems);
  }, [user]);

  const filtered = useMemo(
    () =>
      filter === "all" ? items : items.filter((i) => i.category === filter),
    [items, filter],
  );

  async function onDelete(item: WardrobeItem) {
    if (!user) return;
    if (!confirm(`Remove “${item.name}” from your closet?`)) return;
    setBusyId(item.id);
    try {
      await deleteWardrobeItem(user.uid, item);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="space-y-8">
      <div className="fade-up flex flex-wrap items-end justify-between gap-4">
        <div>
          <span className="pill">Live sync</span>
          <h1 className="mt-3 font-display text-4xl">My Closet</h1>
          <p className="mt-1 text-sm text-muted">
            {items.length} piece{items.length === 1 ? "" : "s"} · updates as you go
          </p>
        </div>
        <Button onClick={() => setShowAdd((v) => !v)}>
          {showAdd ? "Close" : "Add item"}
        </Button>
      </div>

      {showAdd && user && (
        <div className="fade-up">
          <AddItemForm userId={user.uid} onCreated={() => setShowAdd(false)} />
        </div>
      )}

      <div className="flex items-center gap-3">
        <label className="text-sm text-muted">Filter</label>
        <Select
          className="max-w-xs"
          value={filter}
          onChange={(e) =>
            setFilter(e.target.value as WardrobeCategory | "all")
          }
        >
          <option value="all">All categories</option>
          {WARDROBE_CATEGORIES.map((c) => (
            <option key={c.value} value={c.value}>
              {c.label}
            </option>
          ))}
        </Select>
      </div>

      {filtered.length === 0 ? (
        <EmptyState
          emoji="✧"
          title="Nothing here yet"
          description="Add a photo of something you love wearing — colour and category help styling later."
          action={
            <Button onClick={() => setShowAdd(true)}>Add clothing</Button>
          }
        />
      ) : (
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-4">
          {filtered.map((item) => (
            <article
              key={item.id}
              className="item-card surface overflow-hidden"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={item.imageUrl}
                alt={item.name}
                className="aspect-[3/4] w-full object-cover"
              />
              <div className="space-y-2 p-3">
                <div>
                  <p className="truncate font-medium">{item.name}</p>
                  <p className="text-xs capitalize text-muted">
                    {item.category} · {item.colour}
                  </p>
                </div>
                <Button
                  variant="ghost"
                  className="w-full text-danger"
                  disabled={busyId === item.id}
                  onClick={() => onDelete(item)}
                >
                  {busyId === item.id ? "Removing…" : "Remove"}
                </Button>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
