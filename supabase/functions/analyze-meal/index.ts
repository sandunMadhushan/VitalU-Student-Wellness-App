import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

// AI provider: NVIDIA NIM (DeepSeek V4.1 Flash, multimodal) when NVIDIA_API_KEY is set,
// otherwise Gemini (GEMINI_API_KEY). Optional overrides: NVIDIA_MODEL, GEMINI_MODEL.

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

const PROMPT = `You are a nutrition assistant for Sri Lankan university students.
Identify the meal in the photo (Sri Lankan dishes such as rice and curry, string hoppers, kottu, parippu, pol sambol are common).
Estimate the portion shown and its nutrition. If the photo is not food, return {"name": null}.
Return ONLY JSON (no markdown, no commentary):
{
  "name": string (short dish name, e.g. "Rice & Dhal Curry with Gotukola"),
  "kcal": number,
  "carbs_g": number,
  "protein_g": number,
  "fat_g": number,
  "food_groups": array of any of ["grains","fruits","greens","fats_seeds","probiotics","legumes_nuts","herbs_spices","protein"],
  "tags": array of up to 3 short friendly tags (e.g. "High Fibre", "Protein Rich", "Balanced")
}`;

function parseJSON(text: string) {
  const t = text.replace(/<think>[\s\S]*?<\/think>/g, "").trim();
  const s = t.indexOf("{"), e = t.lastIndexOf("}");
  if (s < 0 || e < s) throw new Error("the AI did not return a readable answer");
  return JSON.parse(t.slice(s, e + 1));
}

async function askNvidia(key: string, b64: string, mime: string): Promise<string> {
  const r = await fetch("https://integrate.api.nvidia.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: Deno.env.get("NVIDIA_MODEL") ?? "deepseek-ai/deepseek-v4.1-flash",
      messages: [{
        role: "user",
        content: [
          { type: "text", text: PROMPT },
          { type: "image_url", image_url: { url: `data:${mime};base64,${b64}` } },
        ],
      }],
      temperature: 0.2,
      top_p: 0.95,
      max_tokens: 4096,
      stream: false,
    }),
    signal: AbortSignal.timeout(120_000),
  });
  const out = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`NVIDIA error: ${out?.detail ?? out?.error?.message ?? out?.title ?? r.status}`);
  return out?.choices?.[0]?.message?.content ?? "";
}

async function askGemini(key: string, b64: string, mime: string): Promise<string> {
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";
  const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": key },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ inline_data: { mime_type: mime, data: b64 } }, { text: PROMPT }] }],
      generationConfig: { responseMimeType: "application/json", temperature: 0.2 },
    }),
  });
  const out = await r.json();
  if (!r.ok) throw new Error(`Gemini error: ${out?.error?.message ?? r.status}`);
  return out?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? "").join("") ?? "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);
  const { data: { user } } = await client.auth.getUser((req.headers.get("Authorization") ?? "").replace("Bearer ", ""));
  if (!user) return json({ error: "Not signed in" }, 401);

  const nvidiaKey = Deno.env.get("NVIDIA_API_KEY");
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!nvidiaKey && !geminiKey) return json({ error: "AI API_KEY is not configured (set NVIDIA_API_KEY)" });
  let body: { image_base64?: string; mime_type?: string } = {};
  try {
    body = await req.json();
  } catch (_) { /* ignore */ }
  if (!body.image_base64) return json({ error: "image_base64 required" }, 400);
  if (body.image_base64.length > 14_000_000) return json({ error: "Image too large" }, 413);
  const mime = body.mime_type ?? "image/jpeg";

  try {
    const text = nvidiaKey ? await askNvidia(nvidiaKey, body.image_base64, mime) : await askGemini(geminiKey!, body.image_base64, mime);
    const parsed = parseJSON(text);
    if (!parsed.name) return json({ error: "No food recognised" });
    return json(parsed);
  } catch (e) {
    return json({ error: `Analysis failed: ${(e as Error).message}` });
  }
});
