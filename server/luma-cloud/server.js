// LUMA cloud save API: a small HTTP service in front of MariaDB/MySQL (same design as the FOUNDERS
// cloud). The game never talks to the database; it talks to this service (behind HTTPS, see
// README.md), which signs players in and keeps their saves.
//
//   POST   /v1/guest                {deviceId}           -> {playerId, token}   new guest player
//   POST   /v1/auth/:provider       {token, nonce?}      -> {playerId, token, linked, switched, providers}
//          provider = apple | google | facebook. With the guest's token in Authorization the identity
//          is bound to that player (linked). If the identity already belongs to another player, that
//          player is signed in instead (switched) and the game asks which save to keep.
//   GET    /v1/me                                 (token) -> {playerId, providers}
//   POST   /v1/unlink/:provider                   (token)
//   POST   /v1/logout                             (token)               forget this token
//   DELETE /v1/me                                 (token)               delete the player and every save
//   GET    /v1/save/:key                          (token) -> {value, updatedAt}   404 when nothing is saved
//   PUT    /v1/save/:key            {value}       (token)
//   GET    /health                                       -> {ok: true}
//   /admin                                               password-protected dashboard (admin.js)
//
// Configuration (environment, e.g. /etc/luma-cloud.env): DB_HOST, DB_PORT, DB_USER, DB_PASSWORD,
// DB_NAME, PORT (default 8788), HOST (default 127.0.0.1), ADMIN_PASSWORD, and the sign-in settings
// APPLE_BUNDLE_IDS, GOOGLE_CLIENT_IDS, FACEBOOK_APP_ID, FACEBOOK_APP_SECRET (see README.md).
'use strict';

const http = require('http');
const crypto = require('crypto');
const mysql = require('mysql2/promise');
const { createVerifier, VerifyError } = require('./verify');

const MAX_BODY = 8 * 1024 * 1024;
const MAX_VALUE = 6 * 1024 * 1024;
const PROVIDERS = ['apple', 'google', 'facebook'];
const BACKUP_EVERY_S = 60 * 60;
const KEEP_BACKUPS = 20;

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');
const newId = () => crypto.randomBytes(16).toString('hex');

// Slows down abuse: at most `limit` events per key in 15 minutes.
function rateLimiter(limit) {
  const hits = new Map();
  const timer = setInterval(() => {
    const now = Date.now();
    for (const [k, v] of hits) if (!v.some((t) => now - t < 15 * 60 * 1000)) hits.delete(k);
  }, 60 * 1000);
  timer.unref();
  return {
    tooMany(key) {
      const now = Date.now();
      const list = (hits.get(key) || []).filter((t) => now - t < 15 * 60 * 1000);
      hits.set(key, list);
      return list.length >= limit;
    },
    note(key) { (hits.get(key) || hits.set(key, []).get(key)).push(Date.now()); },
  };
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY) { reject(new HttpError(413, 'Too large.')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => {
      if (size === 0) return resolve({});
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
      catch { reject(new HttpError(400, 'Body is not JSON.')); }
    });
    req.on('error', reject);
  });
}

const clientIp = (req) => req.headers['x-forwarded-for']?.split(',')[0].trim() || req.socket.remoteAddress;

function validKey(key) {
  if (!/^[A-Za-z0-9_.-]{1,64}$/.test(key)) throw new HttpError(400, 'Bad key.');
  return key;
}

function createApp({ env = process.env, verifier = createVerifier(env), pool } = {}) {
  pool = pool || mysql.createPool({
    host: env.DB_HOST || '127.0.0.1',
    port: Number(env.DB_PORT || 3306),
    user: env.DB_USER || 'luma',
    password: env.DB_PASSWORD || '',
    database: env.DB_NAME || 'luma',
    connectionLimit: 10,
    charset: 'utf8mb4',
  });
  const guestLimit = rateLimiter(30);   // new guests per address
  const authLimit = rateLimiter(30);    // failed sign-ins per address

  async function issueToken(playerId) {
    const token = crypto.randomBytes(32).toString('base64url');
    await pool.execute('INSERT INTO sessions (token_hash, player_id) VALUES (?, ?)', [sha256(token), playerId]);
    return token;
  }

  async function authenticate(req, optional = false) {
    const m = /^Bearer (.+)$/.exec(req.headers.authorization || '');
    if (!m) { if (optional) return null; throw new HttpError(401, 'Not signed in.'); }
    const hash = sha256(m[1]);
    const [rows] = await pool.execute('SELECT player_id FROM sessions WHERE token_hash = ?', [hash]);
    if (rows.length === 0) { if (optional) return null; throw new HttpError(401, 'Not signed in.'); }
    pool.execute('UPDATE sessions SET last_used = NOW() WHERE token_hash = ?', [hash]).catch(() => {});
    pool.execute('UPDATE players SET last_seen = NOW() WHERE id = ?', [rows[0].player_id]).catch(() => {});
    return { playerId: rows[0].player_id, tokenHash: hash, token: m[1] };
  }

  async function providersOf(playerId) {
    const [rows] = await pool.execute('SELECT provider FROM identities WHERE player_id = ? ORDER BY provider', [playerId]);
    return rows.map((r) => r.provider);
  }

  // Keeps an earlier version before a save is overwritten (at most one per hour).
  async function backupBeforeWrite(playerId, key) {
    const [last] = await pool.execute(
      'SELECT TIMESTAMPDIFF(SECOND, MAX(created_at), NOW()) AS age FROM save_backups WHERE player_id = ? AND save_key = ?', [playerId, key]);
    if (last[0].age !== null && Number(last[0].age) < BACKUP_EVERY_S) return;
    const [cur] = await pool.execute('SELECT value FROM saves WHERE player_id = ? AND save_key = ?', [playerId, key]);
    if (cur.length === 0) return;
    await pool.execute('INSERT INTO save_backups (player_id, save_key, value) VALUES (?, ?, ?)', [playerId, key, cur[0].value]);
    await pool.execute(
      `DELETE FROM save_backups WHERE player_id = ? AND id NOT IN
         (SELECT id FROM (SELECT id FROM save_backups WHERE player_id = ? ORDER BY id DESC LIMIT ${KEEP_BACKUPS}) keep_rows)`,
      [playerId, playerId]);
  }

  async function route(req, url) {
    const p = url.pathname;
    if (req.method === 'GET' && p === '/health') {
      await pool.query('SELECT 1');
      return { ok: true };
    }

    if (req.method === 'POST' && p === '/v1/guest') {
      const ip = 'guest:' + clientIp(req);
      if (guestLimit.tooMany(ip)) throw new HttpError(429, 'Too many new players. Try again later.');
      guestLimit.note(ip);
      const id = newId();
      await pool.execute('INSERT INTO players (id) VALUES (?)', [id]);
      return { playerId: id, token: await issueToken(id) };
    }

    const auth = /^\/v1\/auth\/([a-z]+)$/.exec(p);
    if (auth && req.method === 'POST') {
      const provider = auth[1];
      if (!PROVIDERS.includes(provider)) throw new HttpError(404, 'Unknown sign-in provider.');
      const ip = 'auth:' + clientIp(req);
      if (authLimit.tooMany(ip)) throw new HttpError(429, 'Too many attempts. Try again in a few minutes.');
      const { token, nonce } = await readBody(req);
      let subject;
      try {
        subject = await verifier[provider](token, nonce);
      } catch (e) {
        if (!(e instanceof VerifyError)) throw e;
        authLimit.note(ip);
        throw new HttpError(401, e.message);
      }
      const me = await authenticate(req, true);
      const [rows] = await pool.execute('SELECT player_id FROM identities WHERE provider = ? AND subject = ?', [provider, subject]);
      if (rows.length > 0) {
        // This account already has a player: sign in to it.
        const owner = rows[0].player_id;
        const same = me && me.playerId === owner;
        return { playerId: owner, token: same ? me.token : await issueToken(owner), linked: false, switched: !same,
          providers: await providersOf(owner) };
      }
      let playerId = me?.playerId;
      if (!playerId) {
        playerId = newId();
        await pool.execute('INSERT INTO players (id) VALUES (?)', [playerId]);
      }
      try {
        await pool.execute('INSERT INTO identities (provider, subject, player_id) VALUES (?, ?, ?)', [provider, subject, playerId]);
      } catch (e) {
        if (e.code === 'ER_DUP_ENTRY') throw new HttpError(409, 'This account was just linked elsewhere. Try again.');
        throw e;
      }
      return { playerId, token: me ? me.token : await issueToken(playerId), linked: true, switched: false,
        providers: await providersOf(playerId) };
    }

    if (req.method === 'GET' && p === '/v1/me') {
      const me = await authenticate(req);
      return { playerId: me.playerId, providers: await providersOf(me.playerId) };
    }

    const unlink = /^\/v1\/unlink\/([a-z]+)$/.exec(p);
    if (unlink && req.method === 'POST') {
      const me = await authenticate(req);
      await pool.execute('DELETE FROM identities WHERE player_id = ? AND provider = ?', [me.playerId, unlink[1]]);
      return { ok: true, providers: await providersOf(me.playerId) };
    }

    if (req.method === 'POST' && p === '/v1/logout') {
      const me = await authenticate(req);
      await pool.execute('DELETE FROM sessions WHERE token_hash = ?', [me.tokenHash]);
      return { ok: true };
    }

    if (req.method === 'DELETE' && p === '/v1/me') {
      const me = await authenticate(req);
      await pool.execute('DELETE FROM save_backups WHERE player_id = ?', [me.playerId]);
      await pool.execute('DELETE FROM players WHERE id = ?', [me.playerId]);
      return { ok: true };
    }

    const save = /^\/v1\/save\/([^/]+)$/.exec(p);
    if (save && req.method === 'GET') {
      const me = await authenticate(req);
      const [rows] = await pool.execute('SELECT value, updated_at FROM saves WHERE player_id = ? AND save_key = ?', [me.playerId, validKey(save[1])]);
      if (rows.length === 0) throw new HttpError(404, 'Nothing saved.');
      return { value: rows[0].value, updatedAt: rows[0].updated_at };
    }
    if (save && req.method === 'PUT') {
      const me = await authenticate(req);
      const key = validKey(save[1]);
      const { value } = await readBody(req);
      if (typeof value !== 'string' || value.length > MAX_VALUE) throw new HttpError(400, 'Value must be a string up to 6 MB.');
      await backupBeforeWrite(me.playerId, key);
      await pool.execute(
        'INSERT INTO saves (player_id, save_key, value) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)',
        [me.playerId, key, value]);
      return { ok: true };
    }

    throw new HttpError(404, 'Not found.');
  }

  const admin = require('./admin')({ env, pool, HttpError, readBody, rateLimiter, clientIp });

  const server = http.createServer(async (req, res) => {
    let status = 200, body;
    try {
      const url = new URL(req.url, 'http://localhost');
      if (await admin(req, res, url)) return;
      body = await route(req, url);
    } catch (e) {
      status = e instanceof HttpError ? e.status : 500;
      body = { error: e instanceof HttpError ? e.message : 'Server error.' };
      if (!(e instanceof HttpError)) console.error(new Date().toISOString(), req.method, req.url, e);
    }
    const text = JSON.stringify(body);
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(text), 'Cache-Control': 'no-store' });
    res.end(text);
  });

  return { server, pool };
}

if (require.main === module) {
  const { server } = createApp();
  const port = Number(process.env.PORT || 8788);
  const host = process.env.HOST || '127.0.0.1';
  server.listen(port, host, () => console.log(`LUMA cloud API on http://${host}:${port}`));
}

module.exports = { createApp, HttpError };
