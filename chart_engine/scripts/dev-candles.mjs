// Local stand-in for the Cloudflare Pages Function during `flutter run -d chrome`.
// Flutter's dev server only serves static files, so /api/candles is missing there.
// This reuses the exact production proxy logic and adds CORS for the dev origin.
import http from 'node:http';

import { onRequest } from '../../backend/reference/candles.js';

if (typeof Response.json !== 'function') {
  Response.json = (data, init = {}) =>
    new Response(JSON.stringify(data), {
      status: init.status ?? 200,
      headers: { 'Content-Type': 'application/json', ...(init.headers ?? {}) },
    });
}

const port = Number(process.env.PORT ?? 8787);
const origin = `http://127.0.0.1:${port}`;

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Accept');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url ?? '/', origin);
  if (req.method !== 'GET' || url.pathname !== '/api/candles') {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not found');
    return;
  }

  try {
    const response = await onRequest({
      request: new Request(url, {
        method: 'GET',
        headers: { Accept: 'application/json' },
      }),
    });

    const headers = {};
    response.headers.forEach((value, key) => {
      if (!['content-encoding', 'transfer-encoding', 'connection'].includes(key)) {
        headers[key] = value;
      }
    });
    headers['access-control-allow-origin'] = '*';

    res.writeHead(response.status, headers);
    res.end(Buffer.from(await response.arrayBuffer()));
  } catch (error) {
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: String(error) }));
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`TraderLog candle dev proxy ready at ${origin}/api/candles`);
  console.log('Leave this running while you use flutter run -d chrome.');
});
