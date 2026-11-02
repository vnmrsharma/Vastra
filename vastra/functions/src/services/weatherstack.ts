import { getFirestore } from "firebase-admin/firestore";
import { getWeatherstackKey } from "../config";

export interface WeatherSnapshot {
  location: string;
  temperatureC: number;
  feelsLikeC: number;
  humidity: number;
  precipMm: number;
  windKph: number;
  description: string;
  isDay: boolean;
  fetchedAt: number;
}

const CACHE_MS = 30 * 60 * 1000;

export async function fetchCurrentWeather(query: string): Promise<WeatherSnapshot> {
  const url = new URL("http://api.weatherstack.com/current");
  url.searchParams.set("access_key", getWeatherstackKey());
  url.searchParams.set("query", query);
  url.searchParams.set("units", "m");

  const res = await fetch(url);
  if (!res.ok) throw new Error(`Weatherstack HTTP ${res.status}`);

  const json = (await res.json()) as {
    success?: boolean;
    error?: { info?: string };
    location?: { name?: string; country?: string };
    current?: {
      temperature?: number;
      feelslike?: number;
      humidity?: number;
      precip?: number;
      wind_speed?: number;
      weather_descriptions?: string[];
      is_day?: string;
    };
  };

  if (json.success === false || !json.current || !json.location) {
    throw new Error(json.error?.info || "Weatherstack returned no data");
  }

  return {
    location: [json.location.name, json.location.country].filter(Boolean).join(", "),
    temperatureC: json.current.temperature ?? 0,
    feelsLikeC: json.current.feelslike ?? 0,
    humidity: json.current.humidity ?? 0,
    precipMm: json.current.precip ?? 0,
    windKph: json.current.wind_speed ?? 0,
    description: json.current.weather_descriptions?.[0] ?? "Unknown",
    isDay: json.current.is_day === "yes",
    fetchedAt: Date.now(),
  };
}

/** Weatherstack's free plan rate-limits hard, so share one reading per city for 30 minutes. */
export async function getCachedWeather(city: string): Promise<WeatherSnapshot> {
  const key = city.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").slice(0, 80) || "unknown";
  const ref = getFirestore().collection("weatherCache").doc(key);
  const snap = await ref.get();
  const cached = snap.exists ? (snap.data() as { weather: WeatherSnapshot; fetchedAt: number }) : null;

  if (cached && Date.now() - cached.fetchedAt < CACHE_MS) return cached.weather;

  try {
    const weather = await fetchCurrentWeather(city);
    await ref.set({ weather, fetchedAt: Date.now() });
    return weather;
  } catch (error) {
    if (cached) return cached.weather;
    throw error;
  }
}
