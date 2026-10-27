// LUMA admin dashboard: a password-protected web page (https://<your domain>/admin) for looking after
// players, built like the FOUNDERS dashboard. Lists every player, shows a readable summary of their
// progress, edits the save (with checks so the game accepts it), keeps a copy before every change,
// and manages sign-in (sign out everywhere, unlink Apple/Google/Facebook, delete).
//
// Turned on by ADMIN_PASSWORD in /etc/luma-cloud.env (at least 12 characters). Without it /admin is off.
//
//   GET    /admin                                    the page
//   POST   /admin/api/login        {password}        sets a sign-in cookie (12 hours)
//   POST   /admin/api/logout
//   GET    /admin/api/stats                          totals for the overview
//   GET    /admin/api/players?q=                     players with a short summary of their save
//   GET    /admin/api/players/:id                    player, readable save, devices, copies
//   PUT    /admin/api/players/:id/save   {data}      replace the save's data (checked)
//   PUT    /admin/api/players/:id/quick  {...}       change coins, gems, energy, essence
//   POST   /admin/api/players/:id/restore {backupId}
//   POST   /admin/api/players/:id/account {action: signout|unlink, provider?}
//   DELETE /admin/api/players/:id
//   GET    /admin/api/players/:id/raw                the stored value as a file (manual backup)
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const zlib = require('zlib');

const KEY = 'luma_save';
const SESSION_MS = 12 * 60 * 60 * 1000;
const PAGE = fs.readFileSync(path.join(__dirname, 'admin.html'));
const ISLANDS = ['ember_reef', 'lantern_bay', 'stone_steps', 'rope_isles', 'moon_grove'];

const sha256 = (s) => crypto.createHash('sha256').update(s).digest();

// MARK: - Save format (same as the game's Cloud: "gz:" + base64(gzip(snapshot JSON)))
// snapshot = {format: 1, savedAt, uploadId, device, data: <the game's whole save dictionary>}

function unpack(value) {
  if (value.startsWith('gz:')) value = zlib.gunzipSync(Buffer.from(value.slice(3), 'base64')).toString('utf8');
  return JSON.parse(value);
}

function pack(snapshot) {
  return 'gz:' + zlib.gzipSync(Buffer.from(JSON.stringify(snapshot), 'utf8')).toString('base64');
}

const count = (o) => (o && typeof o === 'object' ? Object.keys(o).length : 0);

function summary(value) {
  try {
    const s = unpack(value);
    const d = s.data || {};
    const merge = d.merge || {};
    const islands = {};
    for (const id of ISLANDS) islands[id] = count(d.islands?.[id]?.completed);
    return {
      savedAt: s.savedAt ?? null, device: s.device ?? null,
      verdantLevels: count(d.progress?.completed), essence: d.progress?.essence ?? 0,
      islands, islandLevels: Object.values(islands).reduce((a, v) => a + v, 0),
      cafeLevel: merge.level ?? null, coins: merge.coins ?? null, gems: merge.gems ?? null, energy: merge.energy ?? null,
      cafeTasks: Array.isArray(merge.tasks_done) ? merge.tasks_done.length : 0,
      locations: count(d.merge_loc),
    };
  } catch {
    return { broken: true };
  }
}

const isCount = (v) => Number.isInteger(v) && v >= 0;

// The checks the game makes when it loads a save (SaveStore.normalize keeps unknown keys, so only
// the shape and the numbers the game relies on are checked).
function problems(data) {
  const p = [];
  if (!data || typeof data !== 'object' || Array.isArray(data)) return ['Save mora biti JSON objekt.'];
  if (!isCount(data.save_version)) p.push('Fali save_version (cijeli broj).');
  if (!data.progress || typeof data.progress !== 'object') p.push('Fali dio "progress".');
  else {
    if (!isCount(data.progress.essence)) p.push('progress.essence mora biti cijeli broj 0 ili veći.');
    if (data.progress.completed && typeof data.progress.completed !== 'object') p.push('progress.completed mora biti objekt.');
  }
  for (const k of ['merge', 'islands', 'merge_loc', 'settings']) {
    if (data[k] !== undefined && (typeof data[k] !== 'object' || Array.isArray(data[k]) || data[k] === null)) p.push(`"${k}" mora biti objekt.`);
  }
  const m = data.merge || {};
  for (const k of ['coins', 'gems', 'energy', 'level', 'xp']) {
    if (m[k] !== undefined && !isCount(m[k])) p.push(`merge.${k} mora biti cijeli broj 0 ili veći.`);
  }
  if (m.tasks_done !== undefined && !Array.isArray(m.tasks_done)) p.push('merge.tasks_done mora biti popis.');
  for (const [id, isl] of Object.entries(data.islands || {})) {
    if (!isl || typeof isl.completed !== 'object') p.push(`islands.${id}.completed mora biti objekt.`);
  }
  return p;
}

module.exports = function createAdmin({ env, pool, HttpError, readBody, rateLimiter, clientIp }) {
  const password = env.ADMIN_PASSWORD || '';
  const enabled = password.length >= 12;
  if (password && !enabled) console.error('ADMIN_PASSWORD is shorter than 12 characters: /admin stays off.');
  const sessions = new Map(); // sha256(token) hex -> expiry
  const limit = rateLimiter(10);
  const secure = env.ADMIN_INSECURE_COOKIE === '1' ? '' : ' Secure;'; // tests run over plain http

  function cookieToken(req) {
    const m = /(?:^|;\s*)luma_admin=([A-Za-z0-9_-]+)/.exec(req.headers.cookie || '');
    return m ? m[1] : null;
  }

  function signedIn(req) {
    const t = cookieToken(req);
    if (!t) return false;
    const key = sha256(t).toString('hex');
    const until = sessions.get(key);
    if (!until || until < Date.now()) { sessions.delete(key); return false; }
    return true;
  }

  function send(res, status, body, headers = {}) {
    const text = JSON.stringify(body);
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(text), 'Cache-Control': 'no-store', ...headers });
    res.end(text);
  }

  async function player(id) {
    const [rows] = await pool.execute('SELECT id, created_at, last_seen FROM players WHERE id = ?', [id]);
    if (rows.length === 0) throw new HttpError(404, 'Nema tog igrača.');
    return rows[0];
  }

  async function currentSnapshot(id) {
    const [saves] = await pool.execute('SELECT value FROM saves WHERE player_id = ? AND save_key = ?', [id, KEY]);
    if (!saves.length) throw new HttpError(404, 'Igrač nema save.');
    return unpack(saves[0].value);
  }

  async function backup(playerId) {
    const [rows] = await pool.execute('SELECT value FROM saves WHERE player_id = ? AND save_key = ?', [playerId, KEY]);
    if (rows.length === 0) return;
    await pool.execute('INSERT INTO save_backups (player_id, save_key, value) VALUES (?, ?, ?)', [playerId, KEY, rows[0].value]);
  }

  // A new uploadId makes the player's device ask which progress to keep the next time it syncs.
  async function writeSnapshot(id, snapshot) {
    snapshot.uploadId = crypto.randomBytes(16).toString('hex');
    snapshot.savedAt = Math.floor(Date.now() / 1000);
    snapshot.device = 'Admin';
    await backup(id);
    await pool.execute(
      'INSERT INTO saves (player_id, save_key, value) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)',
      [id, KEY, pack(snapshot)]);
  }

  async function api(req, res, p, url) {
    if (req.method === 'POST' && p === '/login') {
      const ip = 'admin:' + clientIp(req);
      if (limit.tooMany(ip)) throw new HttpError(429, 'Previše pokušaja. Pokušaj za 15 minuta.');
      const { password: given } = await readBody(req);
      if (!crypto.timingSafeEqual(sha256(String(given || '')), sha256(password))) {
        limit.note(ip);
        throw new HttpError(401, 'Kriva lozinka.');
      }
      const token = crypto.randomBytes(32).toString('base64url');
      sessions.set(sha256(token).toString('hex'), Date.now() + SESSION_MS);
      return send(res, 200, { ok: true }, {
        'Set-Cookie': `luma_admin=${token}; Path=/admin; HttpOnly;${secure} SameSite=Strict; Max-Age=${SESSION_MS / 1000}`,
      });
    }

    // Everything else needs the cookie, and the page's own header (a form on another site cannot send it).
    if (!signedIn(req) || req.headers['x-luma-admin'] !== '1') throw new HttpError(401, 'Nisi prijavljen.');

    if (req.method === 'POST' && p === '/logout') {
      const t = cookieToken(req);
      if (t) sessions.delete(sha256(t).toString('hex'));
      return send(res, 200, { ok: true }, { 'Set-Cookie': `luma_admin=; Path=/admin; HttpOnly;${secure} SameSite=Strict; Max-Age=0` });
    }

    if (req.method === 'GET' && p === '/stats') {
      const [[players]] = await pool.query('SELECT COUNT(*) AS n FROM players');
      const [[active]] = await pool.query('SELECT COUNT(*) AS n FROM players WHERE last_seen > NOW() - INTERVAL 7 DAY');
      const [[today]] = await pool.query('SELECT COUNT(*) AS n FROM players WHERE last_seen > NOW() - INTERVAL 1 DAY');
      const [[saves]] = await pool.query('SELECT COUNT(*) AS n FROM saves');
      const [byProvider] = await pool.query('SELECT provider, COUNT(*) AS n FROM identities GROUP BY provider');
      const providers = {};
      for (const r of byProvider) providers[r.provider] = Number(r.n);
      return send(res, 200, { players: Number(players.n), active7d: Number(active.n), active1d: Number(today.n), saves: Number(saves.n), providers });
    }

    if (req.method === 'GET' && p === '/players') {
      const q = (url.searchParams.get('q') || '').trim().toLowerCase();
      const [rows] = await pool.execute(
        `SELECT p.id, p.created_at, p.last_seen, s.value, s.updated_at,
                (SELECT COUNT(*) FROM sessions x WHERE x.player_id = p.id) AS devices,
                (SELECT GROUP_CONCAT(provider ORDER BY provider) FROM identities i WHERE i.player_id = p.id) AS providers
           FROM players p LEFT JOIN saves s ON s.player_id = p.id AND s.save_key = ?
          ORDER BY p.last_seen DESC LIMIT 2000`, [KEY]);
      let list = rows.map((r) => ({
        id: r.id, createdAt: r.created_at, lastSeen: r.last_seen, devices: Number(r.devices),
        providers: r.providers ? String(r.providers).split(',') : [],
        savedAt: r.updated_at, save: r.value ? summary(r.value) : null,
      }));
      if (q) list = list.filter((x) => x.id.includes(q) || x.providers.some((v) => v.includes(q)) || (x.save?.device || '').toLowerCase().includes(q));
      return send(res, 200, { players: list });
    }

    const m = /^\/players\/([0-9a-f]{32})(\/[a-z]+)?$/.exec(p);
    if (!m) throw new HttpError(404, 'Not found.');
    const [, id, action = ''] = m;
    const who = await player(id);

    if (req.method === 'GET' && action === '') {
      const [saves] = await pool.execute('SELECT value, updated_at FROM saves WHERE player_id = ? AND save_key = ?', [id, KEY]);
      const [copies] = await pool.execute('SELECT id, created_at FROM save_backups WHERE player_id = ? AND save_key = ? ORDER BY id DESC', [id, KEY]);
      const [devices] = await pool.execute('SELECT created_at, last_used FROM sessions WHERE player_id = ? ORDER BY last_used DESC', [id]);
      const [ids] = await pool.execute('SELECT provider, created_at FROM identities WHERE player_id = ? ORDER BY provider', [id]);
      let snapshot = null, error = null, sum = null;
      if (saves.length) {
        try { snapshot = unpack(saves[0].value); sum = summary(saves[0].value); }
        catch (e) { error = 'Save se ne može pročitati: ' + e.message; }
      }
      return send(res, 200, { player: who, devices, identities: ids, savedAt: saves[0]?.updated_at ?? null, snapshot, summary: sum, error, backups: copies });
    }

    if (req.method === 'GET' && action === '/raw') {
      const [saves] = await pool.execute('SELECT value FROM saves WHERE player_id = ? AND save_key = ?', [id, KEY]);
      if (!saves.length) throw new HttpError(404, 'Igrač nema save.');
      res.writeHead(200, {
        'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store',
        'Content-Disposition': `attachment; filename="luma_save_${id}_${new Date().toISOString().slice(0, 10)}.txt"`,
      });
      return res.end(saves[0].value);
    }

    if (req.method === 'PUT' && action === '/save') {
      const { data } = await readBody(req);
      const bad = problems(data);
      if (bad.length) return send(res, 400, { error: 'Nisam spremio, igra bi odbila ovaj save.', problems: bad });
      const snapshot = await currentSnapshot(id);
      snapshot.data = data;
      await writeSnapshot(id, snapshot);
      return send(res, 200, { ok: true });
    }

    if (req.method === 'PUT' && action === '/quick') {
      const body = await readBody(req);
      const snapshot = await currentSnapshot(id);
      const d = snapshot.data || (snapshot.data = {});
      d.merge = d.merge || {};
      d.progress = d.progress || {};
      const fields = { coins: d.merge, gems: d.merge, energy: d.merge, essence: d.progress };
      const bad = [];
      for (const [k, target] of Object.entries(fields)) {
        if (body[k] === undefined || body[k] === '' || body[k] === null) continue;
        const v = Number(body[k]);
        if (!isCount(v) || v > 10000000) bad.push(`${k} mora biti cijeli broj od 0 do 10 000 000.`);
        else target[k] = v;
      }
      if (bad.length) return send(res, 400, { error: 'Nisam spremio.', problems: bad });
      const more = problems(d);
      if (more.length) return send(res, 400, { error: 'Nisam spremio, igra bi odbila ovaj save.', problems: more });
      await writeSnapshot(id, snapshot);
      return send(res, 200, { ok: true });
    }

    if (req.method === 'POST' && action === '/restore') {
      const { backupId } = await readBody(req);
      const [rows] = await pool.execute('SELECT value FROM save_backups WHERE id = ? AND player_id = ?', [Number(backupId), id]);
      if (!rows.length) throw new HttpError(404, 'Nema te kopije.');
      await writeSnapshot(id, unpack(rows[0].value));
      return send(res, 200, { ok: true });
    }

    if (req.method === 'POST' && action === '/account') {
      const body = await readBody(req);
      if (body.action === 'signout') {
        await pool.execute('DELETE FROM sessions WHERE player_id = ?', [id]);
      } else if (body.action === 'unlink') {
        await pool.execute('DELETE FROM identities WHERE player_id = ? AND provider = ?', [id, String(body.provider || '')]);
      } else {
        throw new HttpError(400, 'Nepoznata radnja.');
      }
      return send(res, 200, { ok: true });
    }

    if (req.method === 'DELETE' && action === '') {
      await backup(id);
      await pool.execute('DELETE FROM players WHERE id = ?', [who.id]);
      return send(res, 200, { ok: true });
    }

    throw new HttpError(404, 'Not found.');
  }

  // Returns true when the request was for /admin.
  return async function handle(req, res, url) {
    const p = url.pathname;
    if (p !== '/admin' && p !== '/admin/' && !p.startsWith('/admin/api/')) return false;
    try {
      if (p === '/admin' || p === '/admin/') {
        if (!enabled) throw new HttpError(404, 'Admin is off. Set ADMIN_PASSWORD (12+ characters) in /etc/luma-cloud.env.');
        res.writeHead(200, {
          'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', 'X-Frame-Options': 'DENY',
          'Content-Security-Policy': "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; frame-ancestors 'none'",
          'Referrer-Policy': 'no-referrer',
        });
        res.end(PAGE);
        return true;
      }
      if (!enabled) throw new HttpError(404, 'Admin is off.');
      await api(req, res, p.slice('/admin/api'.length), url);
    } catch (e) {
      const status = e instanceof HttpError ? e.status : 500;
      if (!(e instanceof HttpError)) console.error(new Date().toISOString(), 'admin', req.method, req.url, e);
      if (!res.headersSent) send(res, status, { error: e instanceof HttpError ? e.message : 'Greška na serveru.' });
    }
    return true;
  };
};

module.exports.problems = problems;
module.exports.pack = pack;
module.exports.unpack = unpack;
module.exports.summary = summary;
