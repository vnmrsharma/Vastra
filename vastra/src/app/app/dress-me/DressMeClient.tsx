"use client";

import { useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { useAuth } from "@/lib/auth/AuthProvider";
import { dressMeToday } from "@/lib/api/functions";
import { OCCASIONS, type Occasion } from "@/types/domain";

type Suggestion = Awaited<ReturnType<typeof dressMeToday>>["suggestions"][number];
type Weather = Awaited<ReturnType<typeof dressMeToday>>["weather"];

export function DressMeClient() {
  const search = useSearchParams();
  const { profile } = useAuth();
  const initial = (search.get("occasion") as Occasion) || "casual";
  const [occasion, setOccasion] = useState<Occasion>(
    OCCASIONS.some((o) => o.value === initial) ? initial : "casual",
  );
  const [city, setCity] = useState(profile?.preferredCity ?? "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [weather, setWeather] = useState<Weather>(null);
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);

  const weatherLine = useMemo(() => {
    if (!weather) return null;
    return `${weather.location} · ${Math.round(weather.temperatureC)}°C · ${weather.description}`;
  }, [weather]);

  async function onSubmit() {
    setBusy(true);
    setError(null);
    setNote(null);
    try {
      const result = await dressMeToday({
        occasion,
        city: city.trim(),
      });
      setWeather(result.weather);
      setSuggestions(result.suggestions || []);
      if (result.note) setNote(result.note);
      if (result.weatherNote && !result.weather) {
        setNote(result.weatherNote);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not style you");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div className="fade-up">
        <span className="pill">Occasion · weather · your closet</span>
        <h1 className="mt-3 font-display text-4xl">Dress me today</h1>
        <p className="mt-2 text-muted">
          Soft, practical looks from what you already own — tuned to the day.
        </p>
      </div>

      <form
        className="surface fade-up-delay space-y-4 p-6"
        onSubmit={(e) => {
          e.preventDefault();
          void onSubmit();
        }}
      >
        <label className="block space-y-1.5 text-sm">
          <span>Occasion</span>
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
        <label className="block space-y-1.5 text-sm">
          <span>City</span>
          <Input
            value={city}
            onChange={(e) => setCity(e.target.value)}
            placeholder="London"
          />
        </label>
        <Button type="submit" disabled={busy} className="w-full sm:w-auto">
          {busy ? "Styling you…" : "Get suggestions"}
        </Button>
        {error && (
          <p className="rounded-xl bg-danger/10 px-3 py-2 text-sm text-danger">
            {error}
          </p>
        )}
      </form>

      {weatherLine && (
        <div className="rounded-2xl border border-border bg-mint/50 px-4 py-3 text-sm text-success">
          {weatherLine}
          {weather ? (
            <span className="text-muted">
              {" "}
              · feels like {Math.round(weather.feelsLikeC)}°C
              {weather.precipMm > 0 ? " · rain likely" : ""}
            </span>
          ) : null}
        </div>
      )}

      {note && !suggestions.length && (
        <EmptyState
          title="Need a little more closet"
          description={note}
          action={
            <Link href="/app/closet">
              <Button>Add pieces</Button>
            </Link>
          }
        />
      )}

      {suggestions.length > 0 && (
        <div className="space-y-4">
          {suggestions.map((s, idx) => (
            <article key={`${s.title}-${idx}`} className="surface fade-up p-5">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <p className="text-xs uppercase tracking-[0.18em] text-burgundy">
                    Look {idx + 1}
                  </p>
                  <h2 className="font-display text-2xl">{s.title}</h2>
                  <p className="mt-1 text-sm text-muted">{s.reason}</p>
                </div>
                <Link href="/app/try-on">
                  <Button variant="soft">Try on</Button>
                </Link>
              </div>
              <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-3">
                {s.items?.map((item) =>
                  item ? (
                    <div
                      key={item.id}
                      className="overflow-hidden rounded-xl border border-border bg-ivory"
                    >
                      {item.imageUrl ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={item.imageUrl}
                          alt={item.name}
                          className="aspect-square w-full object-cover"
                        />
                      ) : (
                        <div className="aspect-square bg-ivory-deep" />
                      )}
                      <div className="p-2">
                        <p className="truncate text-xs font-medium">{item.name}</p>
                        <p className="truncate text-[11px] capitalize text-muted">
                          {item.category} · {item.colour}
                        </p>
                      </div>
                    </div>
                  ) : null,
                )}
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
