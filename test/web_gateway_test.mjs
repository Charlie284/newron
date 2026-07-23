import assert from 'node:assert/strict';
import test from 'node:test';

import {onRequest} from '../functions/api/[[path]].js';

async function withMockFetch(mockFetch, callback) {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = mockFetch;
  try {
    await callback();
  } finally {
    globalThis.fetch = originalFetch;
  }
}

test('models are fetched server-side from the configured upstream', async () => {
  await withMockFetch(async (url) => {
    assert.equal(url, 'https://upstream.example/v1/models');
    return Response.json({'data': []});
  }, async () => {
    const response = await onRequest({
      env: {NEWRON_UPSTREAM_API_BASE_URL: 'https://upstream.example/v1/'},
      params: {path: ['models']},
      request: new Request('https://newron.example/api/models'),
    });

    assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'public, max-age=300');
  });
});

test('chat requests preserve JSON bodies without exposing CORS', async () => {
  const payload = {'model': 'test', 'messages': []};

  await withMockFetch(async (url, init) => {
    assert.equal(url, 'https://upstream.example/v1/chat/completions');
    assert.equal(init.method, 'POST');
    assert.deepEqual(JSON.parse(new TextDecoder().decode(init.body)), payload);
    return Response.json({'choices': []});
  }, async () => {
    const response = await onRequest({
      env: {NEWRON_UPSTREAM_API_BASE_URL: 'https://upstream.example/v1'},
      params: {path: ['chat', 'completions']},
      request: new Request('https://newron.example/api/chat/completions', {
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify(payload),
      }),
    });

    assert.equal(response.status, 200);
  });
});

test('RSS proxy rejects hosts outside the app feed allowlist', async () => {
  let fetchCalled = false;

  await withMockFetch(async () => {
    fetchCalled = true;
    return new Response();
  }, async () => {
    const response = await onRequest({
      env: {},
      params: {path: ['rss']},
      request: new Request(
        'https://newron.example/api/rss?url=http%3A%2F%2Flocalhost%2Fsecret',
      ),
    });

    assert.equal(response.status, 400);
    assert.equal(fetchCalled, false);
  });
});

test('RSS proxy returns allowed feed content', async () => {
  await withMockFetch(async (url) => {
    assert.equal(url.href, 'https://www.theguardian.com/world/rss');
    return new Response('<rss><channel /></rss>', {
      headers: {'content-type': 'application/rss+xml'},
    });
  }, async () => {
    const response = await onRequest({
      env: {},
      params: {path: ['rss']},
      request: new Request(
        'https://newron.example/api/rss?url=https%3A%2F%2Fwww.theguardian.com%2Fworld%2Frss',
      ),
    });

    assert.equal(response.status, 200);
    assert.equal(response.headers.get('content-type'), 'application/rss+xml');
    assert.equal(await response.text(), '<rss><channel /></rss>');
  });
});
