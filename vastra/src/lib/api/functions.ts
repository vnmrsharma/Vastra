import { getFirebaseAuth } from "@/lib/firebase/client";

const baseUrl = process.env.NEXT_PUBLIC_FUNCTIONS_URL?.replace(/\/$/, "") ?? "";

export function getFunctionsBaseUrl() {
  return baseUrl;
}

async function authHeader() {
  const user = getFirebaseAuth().currentUser;
  if (!user) throw new Error("Not signed in");
  const token = await user.getIdToken();
  return { Authorization: `Bearer ${token}` };
}

export async function callFunction<TResponse>(
  path: string,
  body?: Record<string, unknown>,
  init?: RequestInit,
): Promise<TResponse> {
  if (!baseUrl) {
    throw new Error(
      "Functions URL not configured. Set NEXT_PUBLIC_FUNCTIONS_URL after deploying Cloud Functions.",
    );
  }

  const headers: Record<string, string> = {
    ...(await authHeader()),
    ...(init?.headers as Record<string, string> | undefined),
  };

  const method = (init?.method ?? (body ? "POST" : "GET")).toUpperCase();
  if (body && method !== "GET") {
    headers["Content-Type"] = "application/json";
  }

  const url =
    method === "GET" && body
      ? `${baseUrl}${path}?${new URLSearchParams(
          Object.entries(body).map(([k, v]) => [k, String(v)]),
        )}`
      : `${baseUrl}${path}`;

  const res = await fetch(url, {
    ...init,
    method,
    headers,
    body: body && method !== "GET" ? JSON.stringify(body) : init?.body,
  });

  const text = await res.text();
  let data: unknown = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { error: text };
  }

  if (!res.ok) {
    const err =
      typeof data === "object" && data && "error" in data
        ? String((data as { error: string }).error)
        : text || `Function error ${res.status}`;
    throw new Error(err);
  }

  return data as TResponse;
}

export async function startTryOn(input: {
  personImageUrl: string;
  garmentImageUrl: string;
  garmentCategory: string;
  productId?: string | null;
  outfitId?: string | null;
  wardrobeItemId?: string | null;
}) {
  return callFunction<{
    jobId: string;
    taskId: string;
    status: string;
  }>("/startTryOn", input);
}

export async function pollTryOn(jobId: string) {
  return callFunction<{
    status: "success" | "error" | "processing";
    resultUrl?: string | null;
    resultPath?: string | null;
    error?: string | null;
    jobId: string;
  }>("/pollTryOn", { jobId }, { method: "POST" });
}

export async function dressMeToday(input: {
  occasion: string;
  city: string;
}) {
  return callFunction<{
    weather: {
      location: string;
      temperatureC: number;
      feelsLikeC: number;
      humidity: number;
      precipMm: number;
      windKph: number;
      description: string;
      isDay: boolean;
    } | null;
    weatherNote?: string | null;
    suggestions: Array<{
      title: string;
      reason: string;
      wardrobeItemIds: string[];
      items: Array<{
        id: string;
        name: string;
        category: string;
        colour: string;
        imageUrl: string | null;
      }>;
    }>;
    note?: string;
    wardrobeCount?: number;
  }>("/dressMeToday", input);
}

export async function analyzeInspiration(input: {
  imageUrl?: string;
  imageBase64?: string;
  mimeType?: string;
}) {
  return callFunction<{
    components: Array<{
      category: string;
      colour: string;
      pattern: string | null;
      styleDescription: string;
      confidence: number;
    }>;
  }>("/analyzeInspiration", input);
}

export async function pollTryOnUntilDone(
  jobId: string,
  opts?: { intervalMs?: number; timeoutMs?: number; onTick?: (status: string) => void },
) {
  const intervalMs = opts?.intervalMs ?? 4000;
  const timeoutMs = opts?.timeoutMs ?? 120000;
  const started = Date.now();

  while (Date.now() - started < timeoutMs) {
    const result = await pollTryOn(jobId);
    opts?.onTick?.(result.status);
    if (result.status === "success" || result.status === "error") {
      return result;
    }
    await new Promise((r) => setTimeout(r, intervalMs));
  }

  throw new Error("Try-on timed out — please retry in a moment.");
}
