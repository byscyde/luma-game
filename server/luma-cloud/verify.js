// Checks sign-in tokens from Apple, Google and Facebook and returns the provider's stable user
// id ("subject"). Nothing else about the person is kept.
//
//   Apple     identity token (JWT, RS256) from Sign in with Apple; audience = the app's bundle id
//   Google    ID token (JWT, RS256) from Google Sign-In; audience = one of our OAuth client ids
//   Facebook  either an access token (checked with the Graph API debug_token call) or, from iOS
//             Limited Login, an OIDC authentication token (JWT, RS256) with audience = our app id
//
// Public keys (JWKS) are fetched over HTTPS and cached for an hour.
'use strict';

const crypto = require('crypto');

const DEFAULTS = {
  appleJwks: 'https://appleid.apple.com/auth/keys',
  googleJwks: 'https://www.googleapis.com/oauth2/v3/certs',
  facebookJwks: 'https://limited.facebook.com/.well-known/oauth/openid/jwks/',
  facebookGraph: 'https://graph.facebook.com',
};

class VerifyError extends Error {}

const list = (s) => String(s || '').split(',').map((x) => x.trim()).filter(Boolean);
const b64json = (part) => JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));

function createVerifier(env = process.env, fetchImpl = fetch) {
  const urls = {
    appleJwks: env.APPLE_JWKS_URL || DEFAULTS.appleJwks,
    googleJwks: env.GOOGLE_JWKS_URL || DEFAULTS.googleJwks,
    facebookJwks: env.FACEBOOK_JWKS_URL || DEFAULTS.facebookJwks,
    facebookGraph: env.FACEBOOK_GRAPH_URL || DEFAULTS.facebookGraph,
  };
  const appleAudiences = list(env.APPLE_BUNDLE_IDS);
  const googleAudiences = list(env.GOOGLE_CLIENT_IDS);
  const facebookAppId = String(env.FACEBOOK_APP_ID || '');
  const facebookSecret = String(env.FACEBOOK_APP_SECRET || '');
  const cache = new Map(); // url -> {at, keys}

  async function keys(url, forceReload) {
    const hit = cache.get(url);
    if (hit && !forceReload && Date.now() - hit.at < 60 * 60 * 1000) return hit.keys;
    const r = await fetchImpl(url);
    if (!r.ok) throw new VerifyError('Could not load signing keys.');
    const body = await r.json();
    const out = new Map();
    for (const k of body.keys || []) if (k.kid && k.kty === 'RSA') out.set(k.kid, k);
    cache.set(url, { at: Date.now(), keys: out });
    return out;
  }

  // Verifies an RS256 JWT against a JWKS and the expected issuers/audiences; returns its claims.
  async function jwt(token, url, issuers, audiences) {
    const parts = String(token || '').split('.');
    if (parts.length !== 3) throw new VerifyError('Malformed token.');
    let header, claims;
    try { header = b64json(parts[0]); claims = b64json(parts[1]); } catch { throw new VerifyError('Malformed token.'); }
    if (header.alg !== 'RS256') throw new VerifyError('Unexpected token algorithm.');
    let jwk = (await keys(url)).get(header.kid);
    if (!jwk) jwk = (await keys(url, true)).get(header.kid); // keys rotate
    if (!jwk) throw new VerifyError('Unknown signing key.');
    const ok = crypto.verify('RSA-SHA256', Buffer.from(parts[0] + '.' + parts[1]),
      crypto.createPublicKey({ key: jwk, format: 'jwk' }), Buffer.from(parts[2], 'base64url'));
    if (!ok) throw new VerifyError('Bad signature.');
    const now = Math.floor(Date.now() / 1000);
    if (typeof claims.exp !== 'number' || claims.exp < now - 60) throw new VerifyError('Token expired.');
    if (!issuers.includes(claims.iss)) throw new VerifyError('Wrong issuer.');
    const aud = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
    if (!aud.some((a) => audiences.includes(a))) throw new VerifyError('Token is for another app.');
    if (!claims.sub) throw new VerifyError('No user id in token.');
    return claims;
  }

  function checkNonce(claims, nonce) {
    if (!nonce) return;
    const hashed = crypto.createHash('sha256').update(String(nonce)).digest('hex');
    if (claims.nonce !== nonce && claims.nonce !== hashed) throw new VerifyError('Nonce does not match.');
  }

  return {
    async apple(token, nonce) {
      if (appleAudiences.length === 0) throw new VerifyError('Apple sign-in is not configured.');
      const c = await jwt(token, urls.appleJwks, ['https://appleid.apple.com'], appleAudiences);
      checkNonce(c, nonce);
      return String(c.sub);
    },
    async google(token, nonce) {
      if (googleAudiences.length === 0) throw new VerifyError('Google sign-in is not configured.');
      const c = await jwt(token, urls.googleJwks, ['accounts.google.com', 'https://accounts.google.com'], googleAudiences);
      checkNonce(c, nonce);
      return String(c.sub);
    },
    async facebook(token, nonce) {
      if (!facebookAppId) throw new VerifyError('Facebook sign-in is not configured.');
      if (String(token || '').split('.').length === 3) {
        const c = await jwt(token, urls.facebookJwks, ['https://www.facebook.com', 'https://limited.facebook.com'], [facebookAppId]);
        checkNonce(c, nonce);
        return String(c.sub);
      }
      if (!facebookSecret) throw new VerifyError('Facebook sign-in is not configured.');
      const q = new URLSearchParams({ input_token: String(token || ''), access_token: `${facebookAppId}|${facebookSecret}` });
      const r = await fetchImpl(`${urls.facebookGraph}/debug_token?${q}`);
      const body = await r.json().catch(() => ({}));
      const d = body.data || {};
      if (!r.ok || !d.is_valid) throw new VerifyError('Facebook token is not valid.');
      if (String(d.app_id) !== facebookAppId) throw new VerifyError('Token is for another app.');
      if (!d.user_id) throw new VerifyError('No user id in token.');
      return String(d.user_id);
    },
  };
}

module.exports = { createVerifier, VerifyError };
