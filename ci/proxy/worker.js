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
    // The whole body is read before answering: bka.de sometimes drops the
    // connection mid-transfer, and a streamed answer without a length then
    // looks complete to the client (3 truncated files with HTTP 200 in
    // diagnose run 40746772308). An incomplete transfer becomes HTTP 502,
    // which the pipeline retries.
    let body;
    try {
      body = await upstream.arrayBuffer();
    } catch (e) {
      return new Response("Upstream transfer failed.", { status: 502 });
    }
    const declared = upstream.headers.get("content-length");
    const encoded = upstream.headers.get("content-encoding");
    if (declared && !encoded && Number(declared) !== body.byteLength) {
      return new Response("Upstream transfer incomplete.", { status: 502 });
    }
    const out = new Headers();
    for (const h of ["content-type", "etag", "last-modified", "content-range"]) {
      const v = upstream.headers.get(h);
      if (v) out.set(h, v);
    }
    out.set("content-length", String(body.byteLength));
    return new Response(body, { status: upstream.status, headers: out });
  },
};
