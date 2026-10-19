const bcrypt   = require('bcrypt');
const jwt      = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const pool     = require('../config/db');

const SALT_ROUNDS = 10;

// ─── helpers ─────────────────────────────────────────────────────────────────
function signToken(user) {
  return jwt.sign(
    { id: user.id, email: user.email, user_type: user.user_type },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
}

// POST /api/auth/register
async function register(req, res) {
  const { email, password, user_type } = req.body;
  if (!email || !password || !user_type) {
    return res.status(400).json({ message: 'email, password and user_type are required' });
  }
  if (!['client', 'restaurant'].includes(user_type)) {
    return res.status(400).json({ message: 'user_type must be client or restaurant' });
  }

  const conn = await pool.getConnection();
  try {
    const [existing] = await conn.query('SELECT id FROM users WHERE email = ?', [email]);
    if (existing.length > 0) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    const hash = await bcrypt.hash(password, SALT_ROUNDS);
    const [result] = await conn.query(
      'INSERT INTO users (email, password_hash, user_type) VALUES (?,?,?)',
      [email, hash, user_type]
    );
    const userId = result.insertId;

    // create empty profile row
    if (user_type === 'client') {
      await conn.query('INSERT INTO client_profiles (user_id) VALUES (?)', [userId]);
    } else {
      await conn.query('INSERT INTO restaurant_profiles (user_id) VALUES (?)', [userId]);
    }

    const user = { id: userId, email, user_type };
    return res.status(201).json({ token: signToken(user), user });
  } finally {
    conn.release();
  }
}

// POST /api/auth/login
async function login(req, res) {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ message: 'email and password are required' });
  }

  const [rows] = await pool.query(
    'SELECT id, email, password_hash, user_type, is_active FROM users WHERE email = ?',
    [email]
  );
  if (rows.length === 0) {
    return res.status(401).json({ message: 'Invalid credentials' });
  }
  const user = rows[0];
  if (!user.is_active) {
    return res.status(403).json({ message: 'Account deactivated' });
  }

  const match = await bcrypt.compare(password, user.password_hash);
  if (!match) {
    return res.status(401).json({ message: 'Invalid credentials' });
  }

  return res.json({ token: signToken(user), user: { id: user.id, email: user.email, user_type: user.user_type } });
}

// POST /api/auth/forgot-password
async function forgotPassword(req, res) {
  const { email } = req.body;
  if (!email) return res.status(400).json({ message: 'email is required' });

  const [rows] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
  // Always return 200 to avoid user enumeration
  if (rows.length === 0) {
    return res.json({ message: 'If this email exists, a reset link has been sent.' });
  }

  const token   = uuidv4();
  const expires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

  await pool.query(
    'UPDATE users SET reset_token = ?, reset_token_expires = ? WHERE id = ?',
    [token, expires, rows[0].id]
  );

  // In production: send email with reset link
  // For dev: return token in response
  return res.json({
    message: 'If this email exists, a reset link has been sent.',
    dev_reset_token: token   // remove in production
  });
}

// POST /api/auth/reset-password
async function resetPassword(req, res) {
  const { token, new_password } = req.body;
  if (!token || !new_password) {
    return res.status(400).json({ message: 'token and new_password are required' });
  }

  const [rows] = await pool.query(
    'SELECT id FROM users WHERE reset_token = ? AND reset_token_expires > NOW()',
    [token]
  );
  if (rows.length === 0) {
    return res.status(400).json({ message: 'Invalid or expired reset token' });
  }

  const hash = await bcrypt.hash(new_password, SALT_ROUNDS);
  await pool.query(
    'UPDATE users SET password_hash = ?, reset_token = NULL, reset_token_expires = NULL WHERE id = ?',
    [hash, rows[0].id]
  );

  return res.json({ message: 'Password reset successfully' });
}

// PUT /api/auth/change-password  (authenticated)
async function changePassword(req, res) {
  const { current_password, new_password } = req.body;
  if (!current_password || !new_password) {
    return res.status(400).json({ message: 'current_password and new_password are required' });
  }

  const [rows] = await pool.query('SELECT password_hash FROM users WHERE id = ?', [req.user.id]);
  const match  = await bcrypt.compare(current_password, rows[0].password_hash);
  if (!match) {
    return res.status(401).json({ message: 'Current password is incorrect' });
  }

  const hash = await bcrypt.hash(new_password, SALT_ROUNDS);
  await pool.query('UPDATE users SET password_hash = ? WHERE id = ?', [hash, req.user.id]);
  return res.json({ message: 'Password changed successfully' });
}

// DELETE /api/auth/account  (authenticated)
async function deleteAccount(req, res) {
  await pool.query('UPDATE users SET is_active = FALSE WHERE id = ?', [req.user.id]);
  return res.json({ message: 'Account deleted successfully' });
}

module.exports = { register, login, forgotPassword, resetPassword, changePassword, deleteAccount };
