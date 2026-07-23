const DEFAULT_UPSTREAM_API_BASE_URL =
  'https://royal-union-f92a.charlh048.workers.dev/v1';
const MAX_RSS_BYTES = 2 * 1024 * 1024;

const allowedRssHosts = new Set([
  'abc13.com',
  'abc7news.com',
  'api.axios.com',
  'english.kyodonews.net',
  'feeds.arstechnica.com',
  'feeds.bbci.co.uk',
  'feeds.feedburner.com',
  'feeds.news24.com',
  'feeds.skynews.com',
  'feeds.washingtonpost.com',
  'finance.yahoo.com',
  'foresthillstimes.com',
  'fortune.com',
  'gizmodo.com',
  'kdvr.com',
  'ktla.com',
  'mexiconewsdaily.com',
  'miamitodaynews.com',
  'nypost.com',
  'observer.com',
  'phys.org',
  'rss.cnn.com',
  'rss.dw.com',
  'rss.nytimes.com',
  'rss.sciam.com',
  'sports.yahoo.com',
  'timesofsandiego.com',
  'tribune.com.pk',
  'wgntv.com',
  'whdh.com',
  'wsvn.com',
  'wtop.com',
  'www.boston.com',
  'www.cbc.ca',
  'www.cbsnews.com',
  'www.cnbc.com',
  'www.cnet.com',
  'www.ctvnews.ca',
  'www.engadget.com',
  'www.espn.com',
  'www.forbes.com',
  'www.france24.com',
  'www.inquirer.net',
  'www.investing.com',
  'www.japantimes.co.jp',
  'www.kron4.com',
  'www.kxan.com',
  'www.latimes.com',
  'www.lemonde.fr',
  'www.mercurynews.com',
  'www.metrotimes.com',
  'www.minnpost.com',
  'www.nasa.gov',
  'www.nature.com',
  'www.nydailynews.com',
  'www.news10.com',
  'www.newsweek.com',
  'www.phillyvoice.com',
  'www.pravda.com.ua',
  'www.premiumtimesng.com',
  'www.publishedreporter.com',
  'www.sciencedaily.com',
  'www.space.com',
  'www.texasobserver.org',
  'www.theguardian.com',
  'www.themoscowtimes.com',
  'www.thestar.com',
  'www.theverge.com',
  'www.twincities.com',
  'www.westword.com',
  'www.wfla.com',
  'www.wired.com',
  'www.wivb.com',
  'www.yahoo.com',
]);

export async function onRequest(context) {
  const path = normalizePath(context.params.path);

  if (path === 'models' && context.request.method === 'GET') {
    return proxyApiRequest(context, 'models');
  }

  if (path === 'chat/completions' && context.request.method === 'POST') {
    return proxyChatRequest(context);
  }

  if (path === 'rss' && context.request.method === 'GET') {
    return proxyRssRequest(context.request);
  }

  return jsonResponse(404, {'error': 'Not found'});
}

function normalizePath(value) {
  return (Array.isArray(value) ? value.join('/') : (value ?? ''))
    .replace(/^\/+|\/+$/g, '');
}

async function proxyApiRequest(context, path) {
  const upstreamBase = normalizedUpstreamBase(context.env);
  const response = await fetch(`${upstreamBase}/${path}`, {
    headers: {
      Accept: 'application/json',
      'HTTP-Referer': context.request.url,
      'X-Title': 'Newron News App',
    },
    signal: context.request.signal,
  });
  return copyResponse(response, 'public, max-age=300');
}

async function proxyChatRequest(context) {
  const contentType = context.request.headers.get('content-type') ?? '';
  if (!contentType.toLowerCase().startsWith('application/json')) {
    return jsonResponse(415, {'error': 'Content-Type must be application/json'});
  }

  const body = await context.request.arrayBuffer();
  if (body.byteLength > 1024 * 1024) {
    return jsonResponse(413, {'error': 'Request body is too large'});
  }

  const upstreamBase = normalizedUpstreamBase(context.env);
  const response = await fetch(`${upstreamBase}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'HTTP-Referer': context.request.url,
      'X-Title': 'Newron News App',
    },
    body,
    signal: context.request.signal,
  });
  return copyResponse(response, 'no-store');
}

async function proxyRssRequest(request) {
  const rawUrl = new URL(request.url).searchParams.get('url');
  let feedUrl;

  try {
    feedUrl = new URL(rawUrl ?? '');
  } catch (_) {
    return jsonResponse(400, {'error': 'A valid RSS URL is required'});
  }

  if (
    !['http:', 'https:'].includes(feedUrl.protocol) ||
    !allowedRssHosts.has(feedUrl.hostname.toLowerCase())
  ) {
    return jsonResponse(400, {'error': 'RSS host is not allowed'});
  }

  const response = await fetch(feedUrl, {
    headers: {
      Accept: 'application/atom+xml, application/rss+xml, application/xml, text/xml, */*',
      'User-Agent': 'Newron/1.0 (+https://github.com/Charlie284)',
    },
    redirect: 'follow',
  });

  if (!response.ok) {
    return jsonResponse(502, {'error': `RSS upstream returned ${response.status}`});
  }

  const body = await response.arrayBuffer();
  if (body.byteLength > MAX_RSS_BYTES) {
    return jsonResponse(502, {'error': 'RSS response is too large'});
  }

  return new Response(body, {
    status: 200,
    headers: {
      'Cache-Control': 'public, max-age=300',
      'Content-Type': response.headers.get('content-type') ?? 'application/xml; charset=utf-8',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function normalizedUpstreamBase(env) {
  const configured = env?.NEWRON_UPSTREAM_API_BASE_URL?.trim();
  return (configured || DEFAULT_UPSTREAM_API_BASE_URL).replace(/\/+$/, '');
}

function copyResponse(response, cacheControl) {
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: {
      'Cache-Control': cacheControl,
      'Content-Type': response.headers.get('content-type') ?? 'application/json; charset=utf-8',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function jsonResponse(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json; charset=utf-8',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}
