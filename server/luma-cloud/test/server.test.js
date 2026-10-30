// End-to-end tests of the API and the admin dashboard against a local MariaDB/MySQL, with fake
// Apple/Google/Facebook key servers (real RS256 signatures, real verification code).
//   sudo mysql -e "CREATE USER IF NOT EXISTS 'luma_test'@'localhost' IDENTIFIED BY 'test'; GRANT ALL ON luma_test.* TO 'luma_test'@'localhost'"
//   npm test        (DB_TEST_* environment overrides the defaults below)
'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const mysql = require('mysql2/promise');
const { createApp } = require('../server');
const { pack, unpack } = require('../admin');

const DB = { host: process.env.DB_TEST_HOST || '127.0.0.1', user: process.env.DB_TEST_USER || 'luma_test',
  password: process.env.DB_TEST_PASSWORD || 'test', database: 'luma_test' };

const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: 'jwk' }), kid: 'k1', alg: 'RS256', use: 'sig' };
const other = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey;

function sign(claims, key = privateKey, kid = 'k1') {
  const enc = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const head = enc({ alg: 'RS256', kid, typ: 'JWT' }) + '.' + enc({ exp: Math.floor(Date.now() / 1000) + 600, ...claims });
  return head + '.' + crypto.sign('RSA-SHA256', Buffer.from(head), key).toString('base64url');
}

let fake, app, base, pool;
before(async () => {
  // fake identity providers
  fake = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://x');
    res.setHeader('Content-Type', 'application/json');
    if (url.pathname === '/jwks') return res.end(JSON.stringify({ keys: [jwk] }));
    if (url.pathname === '/debug_token') {
      const t = url.searchParams.get('input_token');
      if (url.searchParams.get('access_token') !== '111|fb-secret') { res.statusCode = 400; return res.end('{}'); }
      if (t === 'fb-good') return res.end(JSON.stringify({ data: { is_valid: true, app_id: '111', user_id: 'fb-user-1' } }));
      if (t === 'fb-other-app') return res.end(JSON.stringify({ data: { is_valid: true, app_id: '999', user_id: 'x' } }));
      return res.end(JSON.stringify({ data: { is_valid: false } }));
    }
    res.statusCode = 404; res.end('{}');
  });
  await new Promise((r) => fake.listen(0, '127.0.0.1', r));
  const f = `http://127.0.0.1:${fake.address().port}`;

  const admin = await mysql.createConnection({ ...DB, database: undefined, multipleStatements: true });
  const schema = fs.readFileSync(path.join(__dirname, '..', 'schema.sql'), 'utf8').replace(/\bluma\b/g, 'luma_test');
  await admin.query('DROP DATABASE IF EXISTS luma_test');
  await admin.query(schema);
  await admin.end();

  const env = {
    DB_HOST: DB.host, DB_USER: DB.user, DB_PASSWORD: DB.password, DB_NAME: 'luma_test',
    APPLE_BUNDLE_IDS: 'com.scyde.luma', GOOGLE_CLIENT_IDS: 'ios-client,android-client', FACEBOOK_APP_ID: '111', FACEBOOK_APP_SECRET: 'fb-secret',
    APPLE_JWKS_URL: f + '/jwks', GOOGLE_JWKS_URL: f + '/jwks', FACEBOOK_JWKS_URL: f + '/jwks', FACEBOOK_GRAPH_URL: f,
    ADMIN_PASSWORD: 'admin-password-123', ADMIN_INSECURE_COOKIE: '1',
  };
  app = createApp({ env });
  pool = app.pool;
  await new Promise((r) => app.server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${app.server.address().port}`;
});

after(async () => {
  app.server.close();
  fake.close();
  await pool.end();
});

async function call(method, p, body, token, headers = {}) {
  const r = await fetch(base + p, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}), ...headers },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: r.status, json: await r.json().catch(() => null), headers: r.headers };
}

const google = (sub, extra = {}) => sign({ iss: 'https://accounts.google.com', aud: 'ios-client', sub, ...extra });
const apple = (sub, extra = {}) => sign({ iss: 'https://appleid.apple.com', aud: 'com.scyde.luma', sub, ...extra });

test('health, guests and saves', async () => {
  assert.equal((await call('GET', '/health')).status, 200);
  const a = (await call('POST', '/v1/guest', { deviceId: 'phone-a' })).json;
  assert.ok(a.token && a.playerId);
  assert.equal((await call('GET', '/v1/save/luma_save', null, a.token)).status, 404);
  assert.equal((await call('PUT', '/v1/save/luma_save', { value: 'gz:AAAA' }, a.token)).status, 200);
  assert.equal((await call('GET', '/v1/save/luma_save', null, a.token)).json.value, 'gz:AAAA');
  assert.equal((await call('GET', '/v1/save/luma_save', null, 'nope')).status, 401);
  assert.equal((await call('PUT', '/v1/save/bad key!', { value: 'x' }, a.token)).status, 400);
  assert.equal((await call('PUT', '/v1/save/luma_save', { value: 5 }, a.token)).status, 400);
});

test('google sign-in links the guest, a new phone gets the same save', async () => {
  const a = (await call('POST', '/v1/guest', {})).json;
  await call('PUT', '/v1/save/luma_save', { value: 'gz:PHONE-A' }, a.token);
  const linked = (await call('POST', '/v1/auth/google', { token: google('g-1') }, a.token)).json;
  assert.equal(linked.playerId, a.playerId);
  assert.equal(linked.linked, true);
  assert.deepEqual(linked.providers, ['google']);

  const b = (await call('POST', '/v1/guest', {})).json;
  const again = (await call('POST', '/v1/auth/google', { token: sign({ iss: 'accounts.google.com', aud: 'android-client', sub: 'g-1' }) }, b.token)).json;
  assert.equal(again.playerId, a.playerId, 'signed in to the existing player');
  assert.equal(again.switched, true);
  assert.equal((await call('GET', '/v1/save/luma_save', null, again.token)).json.value, 'gz:PHONE-A');

  const fresh = (await call('POST', '/v1/auth/google', { token: google('g-2') })).json;
  assert.ok(fresh.token && fresh.playerId !== a.playerId, 'no guest token: a new player');
});

test('bad tokens are refused', async () => {
  const bad = async (prov, token, nonce) => (await call('POST', `/v1/auth/${prov}`, { token, nonce })).status;
  assert.equal(await bad('google', sign({ iss: 'https://accounts.google.com', aud: 'someone-else', sub: 'x' })), 401, 'wrong audience');
  assert.equal(await bad('google', sign({ iss: 'https://evil.example', aud: 'ios-client', sub: 'x' })), 401, 'wrong issuer');
  assert.equal(await bad('google', sign({ iss: 'https://accounts.google.com', aud: 'ios-client', sub: 'x', exp: 1000 })), 401, 'expired');
  assert.equal(await bad('google', sign({ iss: 'https://accounts.google.com', aud: 'ios-client', sub: 'x' }, other)), 401, 'forged');
  assert.equal(await bad('google', 'not-a-jwt'), 401);
  assert.equal(await bad('apple', apple('a-1', { nonce: crypto.createHash('sha256').update('n1').digest('hex') }), 'n2'), 401, 'nonce');
  assert.equal(await bad('facebook', 'fb-bad'), 401);
  assert.equal(await bad('facebook', 'fb-other-app'), 401);
  assert.equal((await call('POST', '/v1/auth/myspace', { token: 'x' })).status, 404);
});

test('apple and facebook sign-in, unlink, logout, delete account', async () => {
  const g = (await call('POST', '/v1/guest', {})).json;
  const nonce = 'raw-nonce';
  const ap = (await call('POST', '/v1/auth/apple', { token: apple('a-9', { nonce: crypto.createHash('sha256').update(nonce).digest('hex') }), nonce }, g.token)).json;
  assert.equal(ap.playerId, g.playerId);
  const fb = (await call('POST', '/v1/auth/facebook', { token: 'fb-good' }, g.token)).json;
  assert.deepEqual(fb.providers, ['apple', 'facebook']);
  const lim = (await call('POST', '/v1/auth/facebook', { token: sign({ iss: 'https://www.facebook.com', aud: '111', sub: 'fb-user-1' }) })).json;
  assert.equal(lim.playerId, g.playerId, 'iOS Limited Login token finds the same player');

  assert.deepEqual((await call('GET', '/v1/me', null, g.token)).json.providers, ['apple', 'facebook']);
  assert.deepEqual((await call('POST', '/v1/unlink/facebook', {}, g.token)).json.providers, ['apple']);
  assert.equal((await call('POST', '/v1/logout', {}, lim.token)).status, 200);
  assert.equal((await call('GET', '/v1/me', null, lim.token)).status, 401);

  await call('PUT', '/v1/save/luma_save', { value: 'gz:X' }, g.token);
  assert.equal((await call('DELETE', '/v1/me', null, g.token)).status, 200);
  assert.equal((await call('GET', '/v1/me', null, g.token)).status, 401);
  const [rows] = await pool.execute('SELECT COUNT(*) AS n FROM identities WHERE player_id = ?', [g.playerId]);
  assert.equal(Number(rows[0].n), 0, 'identities go with the player');
});

test('admin dashboard', async () => {
  assert.equal((await call('GET', '/admin/api/players', null, null, { 'X-Luma-Admin': '1' })).status, 401);
  assert.equal((await call('POST', '/admin/api/login', { password: 'wrong' })).status, 401);
  const login = await call('POST', '/admin/api/login', { password: 'admin-password-123' });
  assert.equal(login.status, 200);
  const cookie = login.headers.get('set-cookie').split(';')[0];
  const h = { Cookie: cookie, 'X-Luma-Admin': '1' };
  assert.equal((await call('GET', '/admin/api/players', null, null, { Cookie: cookie })).status, 401, 'needs the page header');

  const g = (await call('POST', '/v1/guest', {})).json;
  const data = { save_version: 3, progress: { completed: { w1_l01: {} }, essence: 40 }, merge: { coins: 10, gems: 5, energy: 80, level: 2, tasks_done: ['c1_debris'] },
    islands: { ember_reef: { completed: { er_l01: {}, er_l02: {} } } }, merge_loc: {} };
  await call('PUT', '/v1/save/luma_save', { value: pack({ format: 1, savedAt: 1, uploadId: 'u1', device: 'iPhone', data }) }, g.token);

  const stats = (await call('GET', '/admin/api/stats', null, null, h)).json;
  assert.ok(stats.players >= 1);
  const list = (await call('GET', '/admin/api/players?q=' + g.playerId, null, null, h)).json.players;
  assert.equal(list.length, 1);
  assert.equal(list[0].save.verdantLevels, 1);
  assert.equal(list[0].save.islandLevels, 2);

  const detail = (await call('GET', `/admin/api/players/${g.playerId}`, null, null, h)).json;
  assert.equal(detail.summary.coins, 10);

  assert.equal((await call('PUT', `/admin/api/players/${g.playerId}/quick`, { coins: -5 }, null, h)).status, 400);
  assert.equal((await call('PUT', `/admin/api/players/${g.playerId}/quick`, { coins: 500, essence: 99 }, null, h)).status, 200);
  const saved = unpack((await call('GET', '/v1/save/luma_save', null, g.token)).json.value);
  assert.equal(saved.data.merge.coins, 500);
  assert.equal(saved.data.progress.essence, 99);
  assert.notEqual(saved.uploadId, 'u1', 'the device will ask which progress to keep');

  const broken = await call('PUT', `/admin/api/players/${g.playerId}/save`, { data: { progress: {} } }, null, h);
  assert.equal(broken.status, 400);
  assert.ok(broken.json.problems.length > 0);

  const backups = (await call('GET', `/admin/api/players/${g.playerId}`, null, null, h)).json.backups;
  assert.ok(backups.length >= 1, 'a copy was kept before the change');
  assert.equal((await call('POST', `/admin/api/players/${g.playerId}/restore`, { backupId: backups[backups.length - 1].id }, null, h)).status, 200);
  assert.equal(unpack((await call('GET', '/v1/save/luma_save', null, g.token)).json.value).data.merge.coins, 10);

  assert.equal((await call('POST', `/admin/api/players/${g.playerId}/account`, { action: 'signout' }, null, h)).status, 200);
  assert.equal((await call('GET', '/v1/me', null, g.token)).status, 401);
  assert.equal((await call('DELETE', `/admin/api/players/${g.playerId}`, null, null, h)).status, 200);
  assert.equal((await call('GET', `/admin/api/players/${g.playerId}`, null, null, h)).status, 404);

  const page = await fetch(base + '/admin');
  assert.equal(page.status, 200);
  assert.match(await page.text(), /LUMA Admin/);
});
