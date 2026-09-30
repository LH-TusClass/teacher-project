const { createClient } = require('redis');

let connectPromise = null;

// 首次调用即发起连接；失败后允许下次重试
function connect() {
  if (connectPromise) return connectPromise;
  connectPromise = (async () => {
    const c = createClient({
      socket: {
        host: process.env.REDIS_HOST || '127.0.0.1',
        port: Number(process.env.REDIS_PORT) || 6379,
      },
      password: process.env.REDIS_PASSWORD || undefined,
    });
    c.on('error', (err) => console.error('[redis]', err.message));
    try {
      await c.connect();
      return c;
    } catch (err) {
      console.error('[redis] connect failed:', err.message);
      connectPromise = null; // 下次重试
      return null;
    }
  })();
  return connectPromise;
}

async function withClient(fn) {
  try {
    const c = await connect();
    if (!c || !c.isReady) return null;
    return await fn(c);
  } catch (_) {
    return null;
  }
}

// 读缓存；未命中则调用 loader 并写入（版本号失效策略：每次写库后 INCR）
async function cachedRead(baseKey, loader, ttlSeconds = 300) {
  const c = await connect();
  if (c && c.isReady) {
    try {
      const ver = String((await c.get('cache:ver')) || '0');
      const hit = await c.get(`cache:v${ver}:${baseKey}`);
      if (hit != null) return JSON.parse(hit);
    } catch (_) { /* 缓存不可用则降级直查数据库 */ }
  }
  const value = await loader();
  if (c && c.isReady) {
    try {
      const ver = String((await c.get('cache:ver')) || '0');
      await c.set(`cache:v${ver}:${baseKey}`, JSON.stringify(value), { EX: ttlSeconds });
    } catch (_) { /* 写入失败忽略 */ }
  }
  return value;
}

// 写库后调用：使所有读缓存失效
async function invalidate() {
  return withClient((c) => c.incr('cache:ver'));
}

// AI 分析限流：每个 IP 每分钟最多 max 次，返回是否超限
async function aiRateLimit(ip, max = 5) {
  return withClient(async (c) => {
    const key = `ai:rl:${ip}`;
    const n = await c.incr(key);
    if (n === 1) await c.expire(key, 60);
    return n > max;
  }) || false;
}

async function get(key) {
  return withClient(async (c) => {
    const raw = await c.get(key);
    return raw != null ? JSON.parse(raw) : null;
  });
}

async function set(key, value, ttlSeconds) {
  return withClient((c) => c.set(key, JSON.stringify(value), { EX: ttlSeconds }));
}

async function ping() {
  return withClient((c) => c.ping());
}

module.exports = { cachedRead, invalidate, aiRateLimit, get, set, ping };
