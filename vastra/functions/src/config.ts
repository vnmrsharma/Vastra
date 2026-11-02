export const YOUCAM_BASE = "https://yce-api-01.makeupar.com";

export function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

export function getYouCamKey() {
  return requireEnv("YOUCAM_API_KEY");
}

export function getGeminiKey() {
  return requireEnv("GEMINI_API_KEY");
}

export function getWeatherstackKey() {
  return requireEnv("WEATHERSTACK_API_KEY");
}
