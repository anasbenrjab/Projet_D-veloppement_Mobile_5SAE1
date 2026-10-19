const pool = require('../config/db');
const { normalizeRows } = require('../utils/normalize');

// GET /api/profile/me
async function getMe(req, res) {
  const { id, user_type } = req.user;

  if (user_type === 'client') {
    const [rows] = await pool.query(
      `SELECT u.id, u.email, u.user_type, u.created_at,
              cp.full_name, cp.phone, cp.photo_url,
              cp.dietary_preferences, cp.allergies
       FROM users u
       LEFT JOIN client_profiles cp ON cp.user_id = u.id
       WHERE u.id = ? AND u.is_active = TRUE`,
      [id]
    );
    if (rows.length === 0) return res.status(404).json({ message: 'User not found' });
    return res.json(normalizeRows(rows[0]));
  } else {
    const [rows] = await pool.query(
      `SELECT u.id, u.email, u.user_type, u.created_at,
              rp.id AS profile_id, rp.name, rp.address,
              rp.latitude, rp.longitude, rp.opening_hours,
              rp.cuisine_type, rp.photos, rp.description
       FROM users u
       LEFT JOIN restaurant_profiles rp ON rp.user_id = u.id
       WHERE u.id = ? AND u.is_active = TRUE`,
      [id]
    );
    if (rows.length === 0) return res.status(404).json({ message: 'User not found' });
    return res.json(normalizeRows(rows[0]));
  }
}

// PUT /api/profile/client
async function updateClientProfile(req, res) {
  const { full_name, phone, dietary_preferences, allergies } = req.body;

  await pool.query(
    `UPDATE client_profiles
     SET full_name = COALESCE(?, full_name),
         phone     = COALESCE(?, phone),
         dietary_preferences = COALESCE(?, dietary_preferences),
         allergies           = COALESCE(?, allergies)
     WHERE user_id = ?`,
    [
      full_name            || null,
      phone                || null,
      dietary_preferences  ?? null,   // pass array directly — mysql2 serialises JSON columns
      allergies            ?? null,
      req.user.id
    ]
  );

  return res.json({ message: 'Client profile updated' });
}

// PUT /api/profile/restaurant
async function updateRestaurantProfile(req, res) {
  const { name, address, latitude, longitude, opening_hours, cuisine_type, description } = req.body;

  await pool.query(
    `UPDATE restaurant_profiles
     SET name          = COALESCE(?, name),
         address       = COALESCE(?, address),
         latitude      = COALESCE(?, latitude),
         longitude     = COALESCE(?, longitude),
         opening_hours = COALESCE(?, opening_hours),
         cuisine_type  = COALESCE(?, cuisine_type),
         description   = COALESCE(?, description)
     WHERE user_id = ?`,
    [
      name          || null,
      address       || null,
      latitude      ?? null,
      longitude     ?? null,
      opening_hours ?? null,    // pass object directly — no JSON.stringify
      cuisine_type  || null,
      description   || null,
      req.user.id
    ]
  );

  return res.json({ message: 'Restaurant profile updated' });
}

// POST /api/profile/upload-photo
async function uploadPhoto(req, res) {
  if (!req.file) {
    return res.status(400).json({ message: 'No file uploaded' });
  }

  const photoUrl = `/uploads/${req.file.filename}`;
  const { user_type, id } = req.user;

  if (user_type === 'client') {
    await pool.query('UPDATE client_profiles SET photo_url = ? WHERE user_id = ?', [photoUrl, id]);
  } else {
    // append to photos JSON array — read, modify, write (no JSON.stringify)
    const [rows] = await pool.query('SELECT photos FROM restaurant_profiles WHERE user_id = ?', [id]);
    let photos = rows[0]?.photos ?? [];
    // normalise in case it was stored as string
    if (typeof photos === 'string') {
      try { photos = JSON.parse(photos); } catch (_) { photos = []; }
    }
    if (!Array.isArray(photos)) photos = [];
    photos.push(photoUrl);
    await pool.query('UPDATE restaurant_profiles SET photos = ? WHERE user_id = ?', [photos, id]);
  }

  return res.json({ photo_url: photoUrl });
}

module.exports = { getMe, updateClientProfile, updateRestaurantProfile, uploadPhoto };
