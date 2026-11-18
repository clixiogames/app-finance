// APP FINANCE — price relay (Cloudflare Worker, free plan).
// Browsers block direct requests to Yahoo Finance (no CORS headers), so the website
// sends price requests here and this worker forwards them.
// It ONLY forwards public price/search requests to Yahoo Finance. Nothing is stored or logged.
//
// Usage: https://<your-worker>.workers.dev/?url=<encoded Yahoo URL>

const ALLOWED_HOSTS = ["query1.finance.yahoo.com", "query2.finance.yahoo.com"];
const ALLOWED_PATHS = ["/v1/finance/search", "/v8/finance/chart/"];

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Accept, Content-Type",
  "Access-Control-Max-Age": "86400",
};

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }
    if (request.method !== "GET") {
      return json({ error: "Only GET is allowed" }, 405);
    }
    const target = new URL(request.url).searchParams.get("url");
    if (!target) {
      return json({ ok: true, service: "app-finance price relay" }, 200);
    }
    let url;
    try {
      url = new URL(target);
    } catch {
      return json({ error: "Invalid url" }, 400);
    }
    if (url.protocol !== "https:" || !ALLOWED_HOSTS.includes(url.hostname) ||
        !ALLOWED_PATHS.some((p) => url.pathname.startsWith(p))) {
      return json({ error: "This address is not allowed" }, 403);
    }
    const cache = caches.default;
    const cacheKey = new Request(url.toString(), { method: "GET" });
    let response = await cache.match(cacheKey);
    if (!response) {
      const upstream = await fetch(url.toString(), {
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; AppFinanceRelay/1.0)",
          "Accept": "application/json",
        },
      });
      response = new Response(upstream.body, upstream);
      response.headers.set("Cache-Control", "public, max-age=600");
      if (upstream.ok) {
        ctx.waitUntil(cache.put(cacheKey, response.clone()));
      }
    }
    const out = new Response(response.body, response);
    for (const [k, v] of Object.entries(CORS)) out.headers.set(k, v);
    out.headers.delete("Set-Cookie");
    return out;
  },
};

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}
