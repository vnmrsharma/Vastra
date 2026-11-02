import { YOUCAM_BASE, getYouCamKey } from "../config";

export type GarmentCategory =
  | "full_body"
  | "upper_body"
  | "lower_body"
  | "outer"
  | "shoes"
  | "auto";

export const GARMENT_CATEGORIES: GarmentCategory[] = [
  "full_body",
  "upper_body",
  "lower_body",
  "outer",
  "shoes",
  "auto",
];

function authHeaders() {
  return {
    Authorization: `Bearer ${getYouCamKey()}`,
    "Content-Type": "application/json",
  };
}

/** Uploads raw image bytes through the YouCam File API and returns a file_id (valid 30 days). */
export async function uploadBufferToYouCam(input: {
  buffer: Buffer;
  contentType: string;
  fileName: string;
}): Promise<string> {
  const contentType = input.contentType.includes("png") ? "image/png" : "image/jpg";
  const init = await fetch(`${YOUCAM_BASE}/s2s/v2.0/file`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({
      files: [
        {
          content_type: contentType,
          file_name: input.fileName,
          file_size: input.buffer.length,
        },
      ],
    }),
  });

  if (!init.ok) {
    throw new Error(`YouCam file init failed: ${init.status} ${await init.text()}`);
  }

  const json = (await init.json()) as {
    data: {
      files: Array<{
        file_id: string;
        requests: Array<{ method: string; url: string; headers: Record<string, string> }>;
      }>;
    };
  };

  const file = json.data.files[0];
  const request = file.requests[0];
  const headers: Record<string, string> = {};
  for (const [key, value] of Object.entries(request.headers || {})) {
    if (key.toLowerCase() !== "content-length") headers[key] = value;
  }

  const put = await fetch(request.url, {
    method: request.method || "PUT",
    headers,
    body: new Uint8Array(input.buffer),
  });
  if (!put.ok) {
    throw new Error(`YouCam file upload failed: ${put.status}`);
  }

  return file.file_id;
}

export async function createClothV4Task(input: {
  srcFileId?: string;
  srcFileUrl?: string;
  refFileId?: string;
  refFileUrl?: string;
  garmentCategory: GarmentCategory;
}) {
  const body: Record<string, unknown> = {
    garment_category: input.garmentCategory,
    change_shoes: input.garmentCategory === "full_body",
    filter_multi_person: "off",
  };

  if (input.srcFileId) body.src_file_id = input.srcFileId;
  else if (input.srcFileUrl) body.src_file_url = input.srcFileUrl;
  if (input.refFileId) body.ref_file_id = input.refFileId;
  else if (input.refFileUrl) body.ref_file_url = input.refFileUrl;

  const res = await fetch(`${YOUCAM_BASE}/s2s/v2.0/task/cloth-v4`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(body),
  });

  const text = await res.text();
  if (!res.ok) {
    let code = "";
    try {
      const parsed = JSON.parse(text) as { error_code?: string; error?: string };
      code = parsed.error_code || parsed.error || "";
    } catch {
      code = text;
    }
    throw new Error(code ? `YouCam rejected the request (${code})` : `YouCam error ${res.status}`);
  }

  const json = JSON.parse(text) as { data: { task_id: string } };
  return json.data.task_id;
}

/** Starts YouCam AI Background Removal (1 unit). */
export async function createSodTask(srcFileId: string) {
  const res = await fetch(`${YOUCAM_BASE}/s2s/v2.0/task/sod`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ src_file_id: srcFileId }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`YouCam background removal failed (${res.status})`);
  return (JSON.parse(text) as { data: { task_id: string } }).data.task_id;
}

/** Polls a YouCam task until it finishes and returns the (2-hour) result URL. */
export async function waitForTask(feature: "sod" | "cloth-v4", taskId: string, timeoutMs = 150_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 2500));
    const res = await fetch(`${YOUCAM_BASE}/s2s/v2.0/task/${feature}/${taskId}`, { headers: authHeaders() });
    const text = await res.text();
    if (!res.ok) {
      if (text.includes("InvalidTaskId")) throw new Error("task_expired");
      continue;
    }
    const data = (JSON.parse(text) as {
      data: { task_status: string; error?: string | null; results?: { url?: string } };
    }).data;
    if (data.task_status === "success" && data.results?.url) return data.results.url;
    if (data.task_status === "error") throw new Error(data.error || "unknown_error");
  }
  throw new Error("timeout");
}

export async function getClothV4Task(taskId: string) {
  const res = await fetch(`${YOUCAM_BASE}/s2s/v2.0/task/cloth-v4/${taskId}`, {
    headers: authHeaders(),
  });

  const text = await res.text();
  if (!res.ok) {
    if (text.includes("InvalidTaskId")) {
      return { data: { task_status: "error", error: "task_expired" as string | null } };
    }
    throw new Error(`YouCam poll failed: ${res.status} ${text}`);
  }

  return JSON.parse(text) as {
    data: {
      task_status: "success" | "error" | "running" | string;
      error: string | null;
      results?: { url?: string };
    };
  };
}
