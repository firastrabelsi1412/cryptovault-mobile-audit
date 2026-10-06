'use strict';
/*
 * CryptoVault — SECURED backend (Phase 2c, full Express + JWT rewrite).
 * Replaces the vulnerable json-server (--routes routes.json) entirely.
 *
 * Fixes embodied here:
 *   V6   — ownership enforced server-side; the client can NEVER choose userId.
 *   V5a  — role decisions are made server-side (RS256-signed JWT verified here),
 *          not trusted from a client-decoded token.
 *   V5b  — POST /auth/revoke blacklists the refresh token on logout.
 *   V10c — no /admin/dump-db, /admin/users-with-secrets, /test/faucet; /admin/*
 *          is gated by authenticateJwt + requireAdmin (role + IP allow-list).
 *   V3   — served over HTTPS with a real cert; the Flutter client pins it.
 *   V4   — request logging is metadata only (method + path); never tokens/bodies.
 *   V1   — JWT private key, admin IPs, etc. come from files/env, never hardcoded.
 *
 * No collection is publicly readable. Every data route requires a valid token.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const crypto = require('crypto');
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// ---- configuration (no secrets in source) --------------------------------
const PORT = parseInt(process.env.PORT || '3000', 10);
const HOST = process.env.HOST || '0.0.0.0';
const ISSUER = 'cryptovault';
const ACCESS_TTL = '15m';
const REFRESH_TTL_MS = 1000 * 60 * 60 * 24 * 7; // 7 days
// IPs allowed to touch /admin/* in addition to the role check. Localhost only by default.
const ADMIN_IPS = (process.env.ADMIN_IPS || '127.0.0.1,::1,::ffff:127.0.0.1')
  .split(',').map((s) => s.trim()).filter(Boolean);

const KEYS_DIR = path.join(__dirname, 'keys');
const CERTS_DIR = path.join(__dirname, 'certs');
const PRIVATE_KEY = fs.readFileSync(path.join(KEYS_DIR, 'jwt_private.pem'));
const PUBLIC_KEY = fs.readFileSync(path.join(KEYS_DIR, 'jwt_public.pem'));

// ---- in-memory store (seeded + hashed at boot) ----------------------------
const seed = JSON.parse(fs.readFileSync(path.join(__dirname, 'db.seed.json'), 'utf8'));
const users = seed.users.map((u) => ({
  id: u.id,
  email: u.email,
  role: u.role,
  fullName: u.fullName,
  kycVerified: u.kycVerified,
  passwordHash: bcrypt.hashSync(u.password, 12), // ✅ bcrypt cost 12 (not MD5/plaintext)
}));
const wallets = seed.wallets;
const transactions = seed.transactions;
const refreshStore = new Map(); // refreshToken -> { userId, exp }

const publicUser = (u) => ({ id: u.id, email: u.email, role: u.role, fullName: u.fullName, kycVerified: u.kycVerified });
const findUserByEmail = (email) =>
  users.find((u) => u.email.toLowerCase() === String(email || '').toLowerCase());
const findUserById = (id) => users.find((u) => u.id === id);

function signAccess(u) {
  return jwt.sign({ email: u.email, role: u.role }, PRIVATE_KEY, {
    algorithm: 'RS256',
    subject: String(u.id),
    issuer: ISSUER,
    expiresIn: ACCESS_TTL,
  });
}
function newRefresh(userId) {
  const tok = crypto.randomBytes(32).toString('base64url');
  refreshStore.set(tok, { userId, exp: Date.now() + REFRESH_TTL_MS });
  return tok;
}

// ---- middleware -----------------------------------------------------------
function authenticateJwt(req, res, next) {
  const h = req.headers.authorization || '';
  const tok = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!tok) return res.status(401).json({ error: 'missing token' });
  try {
    const payload = jwt.verify(tok, PUBLIC_KEY, { algorithms: ['RS256'], issuer: ISSUER });
    req.user = { id: parseInt(payload.sub, 10), email: payload.email, role: payload.role };
    return next();
  } catch (e) {
    return res.status(401).json({ error: 'invalid or expired token' });
  }
}

// ✅ V6 — the effective userId is ALWAYS the caller's own id.
// An admin may inspect a specific user via ?userId=, a normal user cannot.
function effectiveUserId(req) {
  if (req.user.role === 'admin' && req.query.userId) {
    return parseInt(req.query.userId, 10);
  }
  return req.user.id;
}

function requireAdmin(req, res, next) {
  const ip = req.ip || '';
  if (!ADMIN_IPS.includes(ip)) return res.status(403).json({ error: 'forbidden (ip not allowed)' });
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'forbidden (not admin)' });
  return next();
}

// ---- app ------------------------------------------------------------------
const app = express();
app.set('trust proxy', true);
app.use(express.json({ limit: '64kb' }));
// ✅ V4 — metadata-only access log. Never log tokens, bodies, or query secrets.
app.use((req, _res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

// --- authentication --------------------------------------------------------
app.post('/auth/login', (req, res) => {
  const { email, password } = req.body || {};
  const u = findUserByEmail(email);
  // Constant-ish response regardless of which factor failed (no user enumeration).
  if (!u || !bcrypt.compareSync(String(password || ''), u.passwordHash)) {
    return res.status(401).json({ error: 'invalid credentials' });
  }
  return res.json({
    accessToken: signAccess(u),
    refreshToken: newRefresh(u.id),
    user: publicUser(u),
  });
});

app.post('/auth/refresh', (req, res) => {
  const { token } = req.body || {};
  const rec = refreshStore.get(token);
  if (!rec || rec.exp < Date.now()) {
    refreshStore.delete(token);
    return res.status(401).json({ error: 'invalid refresh token' });
  }
  const u = findUserById(rec.userId);
  if (!u) return res.status(401).json({ error: 'invalid refresh token' });
  return res.json({ accessToken: signAccess(u) });
});

// ✅ V5b — logout revokes the refresh token server-side.
app.post('/auth/revoke', (req, res) => {
  const { token } = req.body || {};
  refreshStore.delete(token);
  return res.status(204).end();
});

// --- identity / role gate (V5a server-side) --------------------------------
app.get('/me', authenticateJwt, (req, res) => {
  const u = findUserById(req.user.id);
  if (!u) return res.status(404).json({ error: 'not found' });
  return res.json(publicUser(u));
});

// The client uses this to decide whether to render admin UI; the real
// authorization still happens on each /admin route below.
app.get('/admin/whoami', authenticateJwt, (req, res) => {
  return res.json({ isAdmin: req.user.role === 'admin' });
});

// --- ownership-enforced resources (V6) -------------------------------------
app.get('/wallets', authenticateJwt, (req, res) => {
  const uid = effectiveUserId(req);
  if (uid !== req.user.id && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'forbidden' });
  }
  return res.json(wallets.filter((w) => w.userId === uid));
});

app.get('/transactions', authenticateJwt, (req, res) => {
  const uid = effectiveUserId(req);
  if (uid !== req.user.id && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'forbidden' });
  }
  const list = transactions
    .filter((t) => t.userId === uid)
    .sort((a, b) => (a.ts < b.ts ? 1 : -1));
  return res.json(list);
});

// --- admin (V10c): gated, and exposes NO secrets ---------------------------
// NOTE: there is deliberately NO /admin/dump-db, NO /admin/users-with-secrets,
// and NO /test/faucet. Those existed only in the vulnerable build.
app.get('/admin/users', authenticateJwt, requireAdmin, (_req, res) => {
  // Non-sensitive summary only — never passwords, KYC docs, phones, seeds.
  return res.json(users.map(publicUser));
});

// --- default 404 (no open collections) -------------------------------------
app.use((_req, res) => res.status(404).json({ error: 'not found' }));

// ---- start over HTTPS (V3) ------------------------------------------------
const tlsOptions = {
  key: fs.readFileSync(path.join(CERTS_DIR, 'server.key.pem')),
  cert: fs.readFileSync(path.join(CERTS_DIR, 'server.crt.pem')),
};
https.createServer(tlsOptions, app).listen(PORT, HOST, () => {
  console.log(`CryptoVault SECURED API (HTTPS) listening on https://${HOST}:${PORT}`);
  console.log(`Seeded ${users.length} users, ${wallets.length} wallets, ${transactions.length} transactions.`);
  console.log(`Admin IP allow-list: ${ADMIN_IPS.join(', ')}`);
});
