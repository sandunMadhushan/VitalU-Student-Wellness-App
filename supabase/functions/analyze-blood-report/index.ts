import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { encodeBase64 } from "jsr:@std/encoding@1/base64";
import { extractText, getDocumentProxy } from "npm:unpdf@0.12.1";

// AI provider: NVIDIA NIM (DeepSeek V4.1 Flash, multimodal) when NVIDIA_API_KEY is set,
// otherwise Gemini (GEMINI_API_KEY). Optional overrides: NVIDIA_MODEL, GEMINI_MODEL.

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

const PROMPT = `You are a kind, careful health educator for university students in Sri Lanka.
Read the laboratory report (blood test) provided — either the attached image or the REPORT TEXT below. Extract EVERY numeric test result printed on it.
Use the reference ranges printed on the report whenever present; otherwise use widely accepted adult reference ranges.
Never diagnose. Explanations must be gentle, plain English, 1-2 sentences, practical (food, sleep, hydration, sunlight, activity) and suggest seeing a doctor for anything clearly outside range.
If the input is not a lab report or is unreadable, return {"panel_name": null, "summary": "reason", "results": []}.
Return ONLY JSON (no markdown, no commentary) with this shape:
{
  "panel_name": string (short, e.g. "Full Blood Count" or "Lipid Profile"),
  "summary": string (one friendly sentence overview),
  "results": [{
    "name": string (e.g. "Fasting Blood Glucose"),
    "subtitle": string (2-5 word friendly meaning, e.g. "Morning cellular fuel level"),
    "value": number,
    "value_text": string (value exactly as printed),
    "unit": string,
    "ref_low": number|null,
    "ref_high": number|null,
    "reference": string (e.g. "Ref: 70–99 mg/dL" or "Ideal: <200 mg/dL"),
    "status": "optimal"|"normal"|"low"|"high"|"borderline",
    "status_label": string (e.g. "Optimal Zone", "Slightly Low", "Balanced", "High"),
    "category": "metabolic"|"vitamins_minerals"|"lipids"|"blood_count"|"thyroid"|"kidney_liver"|"other",
    "icon": one of "water_drop","cardiology","wb_sunny","bolt","vital_signs","science","bloodtype","monitor_heart","medication",
    "tip_icon": one of "auto_awesome","restaurant","park","psychology","local_cafe","bedtime","directions_walk","water_drop",
    "explanation": string
  }]
}`;

function parseJSON(text: string) {
  const t = text.replace(/<think>[\s\S]*?<\/think>/g, "").trim();
  const s = t.indexOf("{"), e = t.lastIndexOf("}");
  if (s < 0 || e < s) throw new Error("the AI did not return a readable answer");
  return JSON.parse(t.slice(s, e + 1));
}

async function pdfText(bytes: Uint8Array): Promise<string> {
  const pdf = await getDocumentProxy(bytes);
  const { text } = await extractText(pdf, { mergePages: true });
  return (Array.isArray(text) ? text.join("\n") : text).trim();
}

async function askNvidia(key: string, bytes: Uint8Array, mime: string): Promise<string> {
  const content: unknown[] = [];
  if (mime === "application/pdf") {
    const text = await pdfText(bytes);
    if (text.length < 20) throw new Error("This PDF looks like a scan. Please upload a clear photo (JPG/PNG) of the report instead.");
    content.push({ type: "text", text: `${PROMPT}\n\nREPORT TEXT:\n${text.slice(0, 60000)}` });
  } else {
    content.push({ type: "text", text: PROMPT });
    content.push({ type: "image_url", image_url: { url: `data:${mime};base64,${encodeBase64(bytes)}` } });
  }
  const r = await fetch("https://integrate.api.nvidia.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: Deno.env.get("NVIDIA_MODEL") ?? "deepseek-ai/deepseek-v4.1-flash",
      messages: [{ role: "user", content }],
      temperature: 0.2,
      top_p: 0.95,
      max_tokens: 16384,
      stream: false,
    }),
    signal: AbortSignal.timeout(140_000),
  });
  const out = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`NVIDIA error: ${out?.detail ?? out?.error?.message ?? out?.title ?? r.status}`);
  return out?.choices?.[0]?.message?.content ?? "";
}

async function askGemini(key: string, bytes: Uint8Array, mime: string): Promise<string> {
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";
  const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": key },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ inline_data: { mime_type: mime, data: encodeBase64(bytes) } }, { text: PROMPT }] }],
      generationConfig: { responseMimeType: "application/json", temperature: 0.2 },
    }),
  });
  const out = await r.json();
  if (!r.ok) throw new Error(`Gemini error: ${out?.error?.message ?? r.status}`);
  return out?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? "").join("") ?? "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const url = Deno.env.get("SUPABASE_URL")!;
  const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const authHeader = req.headers.get("Authorization") ?? "";
  const { data: { user } } = await service.auth.getUser(authHeader.replace("Bearer ", ""));
  if (!user) return json({ error: "Not signed in" }, 401);

  let reportId = "";
  try {
    reportId = (await req.json()).report_id;
  } catch (_) { /* ignore */ }
  if (!reportId) return json({ error: "report_id required" }, 400);

  const { data: report } = await service.from("blood_reports").select("*").eq("id", reportId).eq("user_id", user.id).maybeSingle();
  if (!report) return json({ error: "Report not found" }, 404);

  const fail = async (msg: string, status = 200) => {
    await service.from("blood_reports").update({ status: "failed", error: msg }).eq("id", reportId);
    return json({ error: msg }, status);
  };

  const nvidiaKey = Deno.env.get("NVIDIA_API_KEY");
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!nvidiaKey && !geminiKey) return await fail("AI API_KEY is not configured (set NVIDIA_API_KEY)");
  await service.from("blood_reports").update({ status: "processing", error: null }).eq("id", reportId);

  const { data: file, error: dlErr } = await service.storage.from("blood-reports").download(report.file_path);
  if (dlErr || !file) return await fail("Could not read the uploaded file");
  const bytes = new Uint8Array(await file.arrayBuffer());
  const mime = report.mime_type ?? "image/jpeg";

  try {
    const text = nvidiaKey ? await askNvidia(nvidiaKey, bytes, mime) : await askGemini(geminiKey!, bytes, mime);
    const parsed = parseJSON(text);
    const results = Array.isArray(parsed.results) ? parsed.results : [];
    if (results.length === 0) return await fail(parsed.summary || "No lab values could be found in this file");
    const { data: updated } = await service.from("blood_reports").update({
      status: "done",
      panel_name: parsed.panel_name ?? "Lab Panel",
      summary: parsed.summary ?? null,
      results,
      error: null,
    }).eq("id", reportId).select().single();
    return json({ report: updated });
  } catch (e) {
    const m = (e as Error).message;
    return await fail(m.startsWith("This PDF") ? m : `Analysis failed: ${m}`);
  }
});
