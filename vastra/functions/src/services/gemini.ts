import { getGeminiKey } from "../config";

const MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";

type Part =
  | { text: string }
  | { inline_data: { mime_type: string; data: string } };

async function callGemini(parts: Part[], json: boolean): Promise<string> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${getGeminiKey()}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts }],
      generationConfig: {
        temperature: 0.6,
        // Thinking adds several seconds of latency that the app UI can't hide.
        thinkingConfig: { thinkingBudget: 0 },
        ...(json ? { responseMimeType: "application/json" } : {}),
      },
    }),
  });

  if (!res.ok) {
    throw new Error(`Gemini error ${res.status}: ${(await res.text()).slice(0, 300)}`);
  }

  const data = (await res.json()) as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  };
  return data.candidates?.[0]?.content?.parts?.map((p) => p.text ?? "").join("") ?? "";
}

export function geminiGenerateText(prompt: string, json = true) {
  return callGemini([{ text: prompt }], json);
}

export function geminiGenerateFromImage(input: {
  prompt: string;
  imageBase64: string;
  mimeType: string;
}) {
  return callGemini(
    [
      { text: input.prompt },
      { inline_data: { mime_type: input.mimeType, data: input.imageBase64 } },
    ],
    true,
  );
}

export function extractJson<T>(raw: string): T {
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const text = (fenced?.[1] ?? raw).trim();
  try {
    return JSON.parse(text) as T;
  } catch {
    const startArr = text.indexOf("[");
    const startObj = text.indexOf("{");
    const useArr = startArr !== -1 && (startObj === -1 || startArr < startObj);
    const slice = useArr
      ? text.slice(startArr, text.lastIndexOf("]") + 1)
      : text.slice(startObj, text.lastIndexOf("}") + 1);
    return JSON.parse(slice) as T;
  }
}
