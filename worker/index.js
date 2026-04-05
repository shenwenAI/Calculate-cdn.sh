/**
 * Cloudflare Worker CDN 后端
 * 功能：检测客户端 IP、地理位置、CDN 节点信息
 * 作者：shc
 */

// CORS 响应头
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

/**
 * 处理 CORS 预检请求
 */
function handleOptions() {
  return new Response(null, {
    status: 204,
    headers: CORS_HEADERS,
  });
}

/**
 * 返回 JSON 响应
 */
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...CORS_HEADERS,
    },
  });
}

/**
 * 获取客户端 IP 信息
 */
function getClientInfo(request) {
  const cf = request.cf || {};
  const ip = request.headers.get('cf-connecting-ip') || '';
  const userAgent = request.headers.get('user-agent') || '';

  return {
    ip,
    ip_version: ip.includes(':') ? 'IPv6' : 'IPv4',
    user_agent: userAgent,
    // 地理位置信息（来自 Cloudflare）
    location: {
      country: cf.country || '',
      country_name: cf.country || '',
      region: cf.region || '',
      region_code: cf.regionCode || '',
      city: cf.city || '',
      postal_code: cf.postalCode || '',
      latitude: cf.latitude || '',
      longitude: cf.longitude || '',
      timezone: cf.timezone || '',
      continent: cf.continent || '',
    },
    // CDN 节点信息
    cdn: {
      colo: cf.colo || '',
      http_protocol: cf.httpProtocol || '',
      tls_version: cf.tlsVersion || '',
      tls_cipher: cf.tlsCipher || '',
      asn: cf.asn || '',
      as_organization: cf.asOrganization || '',
    },
  };
}

/**
 * 处理 /api/ip - 返回客户端 IP 和完整信息
 */
function handleIP(request) {
  return jsonResponse(getClientInfo(request));
}

/**
 * 处理 /api/ip/simple - 仅返回 IP 地址（纯文本）
 */
function handleIPSimple(request) {
  const ip = request.headers.get('cf-connecting-ip') || '';
  return new Response(ip, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      ...CORS_HEADERS,
    },
  });
}

/**
 * 处理 /api/cdn-test - CDN 延迟测试端点
 */
function handleCDNTest(request) {
  const cf = request.cf || {};
  const timestamp = Date.now();

  return jsonResponse({
    timestamp,
    colo: cf.colo || '',
    country: cf.country || '',
    server_time: new Date(timestamp).toISOString(),
    message: 'CDN test endpoint - use timestamp to calculate round-trip latency',
  });
}

/**
 * 处理 /api/trace - 类似 cloudflare /cdn-cgi/trace 的信息
 */
function handleTrace(request) {
  const cf = request.cf || {};
  const ip = request.headers.get('cf-connecting-ip') || '';
  const userAgent = request.headers.get('user-agent') || '';

  const traceInfo = [
    `ip=${ip}`,
    `ts=${Date.now() / 1000}`,
    `ua=${userAgent}`,
    `colo=${cf.colo || ''}`,
    `sliver=none`,
    `http=${cf.httpProtocol || ''}`,
    `loc=${cf.country || ''}`,
    `tls=${cf.tlsVersion || ''}`,
    `sni=plaintext`,
    `warp=off`,
    `gateway=off`,
    `kex=${cf.tlsCipher || ''}`,
  ].join('\n');

  return new Response(traceInfo + '\n', {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      ...CORS_HEADERS,
    },
  });
}

/**
 * 处理 404 路由
 */
function handleNotFound() {
  return jsonResponse(
    {
      error: 'Not Found',
      available_endpoints: [
        'GET /api/ip         - Full client IP & CDN info (JSON)',
        'GET /api/ip/simple  - Client IP only (text)',
        'GET /api/cdn-test   - CDN latency test endpoint (JSON)',
        'GET /api/trace      - Trace info (text, similar to /cdn-cgi/trace)',
      ],
    },
    404
  );
}

/**
 * 路由请求
 */
function routeRequest(request) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, '') || '/';

  switch (path) {
    case '/api/ip':
      return handleIP(request);
    case '/api/ip/simple':
      return handleIPSimple(request);
    case '/api/cdn-test':
      return handleCDNTest(request);
    case '/api/trace':
      return handleTrace(request);
    default:
      if (path === '/' || path === '') {
        return handleIP(request);
      }
      return handleNotFound();
  }
}

export default {
  async fetch(request) {
    if (request.method === 'OPTIONS') {
      return handleOptions();
    }

    if (request.method !== 'GET') {
      return jsonResponse({ error: 'Method not allowed' }, 405);
    }

    return routeRequest(request);
  },
};
