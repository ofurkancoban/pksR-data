// Cloudflare Worker that forwards GET requests to www.bka.de only.
//
// Purpose: test whether requests from Cloudflare reach bka.de more reliably
// than requests from GitHub runners (notes/decisions.md). It does not hide
// who is asking: the pipeline's User-Agent is passed on unchanged, and
// Cloudflare adds a CF-Worker header to every request a Worker makes.
//
// Not an open proxy: only https://www.bka.de/ targets are allowed, and every
// call must carry the shared secret PROXY_KEY (a Worker secret; the same
// value is the GitHub secret BKA_PROXY_KEY).
//
// Call: GET https://<worker>/?url=<encoded bka.de URL>  with header
// X-Proxy-Key: <secret>

export default {
  async fetch(request, env) {
    if (request.method !== "GET") {
      return new Response("Only GET is allowed.", { status: 405 });
    }
    if (!env.PROXY_KEY || request.headers.get("X-Proxy-Key") !== env.PROXY_KEY) {
      return new Response("Forbidden.", { status: 403 });
    }
    const target = new URL(request.url).searchParams.get("url");
    let url;
    try {
      url = new URL(target);
    } catch {
      return new Response("Missing or invalid url parameter.", { status: 400 });
    }
    if (url.protocol !== "https:" || url.hostname !== "www.bka.de") {
      return new Response("Only https://www.bka.de/ is allowed.", { status: 403 });
    }
    const headers = new Headers();
    const ua = request.headers.get("User-Agent");
    if (ua) headers.set("User-Agent", ua);
    const range = request.headers.get("Range");
    if (range) headers.set("Range", range);
    const upstream = await fetch(url.toString(), { headers, redirect: "follow" });
    const out = new Headers();
    for (const h of ["content-type", "content-length", "etag", "last-modified", "content-range"]) {
      const v = upstream.headers.get(h);
      if (v) out.set(h, v);
    }
    return new Response(upstream.body, { status: upstream.status, headers: out });
  },
};
