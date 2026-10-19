const pool = require('../config/db');
const { normalizeRows } = require('../utils/normalize');

// GET /api/favorites/restaurants
async function getFavoriteRestaurants(req, res) {
  const [rows] = await pool.query(
    `SELECT rp.id, rp.name, rp.address, rp.latitude, rp.longitude,
            rp.cuisine_type, rp.photos, rp.description, rp.opening_hours,
            fr.created_at AS favorited_at
     FROM favorite_restaurants fr
     JOIN restaurant_profiles rp ON rp.id = fr.restaurant_id
     WHERE fr.user_id = ?
     ORDER BY fr.created_at DESC`,
    [req.user.id]
  );
  return res.json(normalizeRows(rows));
}

// POST /api/favorites/restaurants/:id
async function addFavoriteRestaurant(req, res) {
  const { id } = req.params;
  try {
    await pool.query(
      'INSERT INTO favorite_restaurants (user_id, restaurant_id) VALUES (?,?)',
      [req.user.id, id]
    );
    return res.status(201).json({ message: 'Added to favorites' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'Already in favorites' });
    }
    throw err;
  }
}

// DELETE /api/favorites/restaurants/:id
async function removeFavoriteRestaurant(req, res) {
  const { id } = req.params;
  await pool.query(
    'DELETE FROM favorite_restaurants WHERE user_id = ? AND restaurant_id = ?',
    [req.user.id, id]
  );
  return res.json({ message: 'Removed from favorites' });
}

// GET /api/favorites/dishes
async function getFavoriteDishes(req, res) {
  const [rows] = await pool.query(
    `SELECT d.id, d.name, d.description, d.price, d.photo_url, d.tags,
            rp.id AS restaurant_id, rp.name AS restaurant_name,
            rp.address AS restaurant_address, rp.cuisine_type,
            fd.created_at AS favorited_at
     FROM favorite_dishes fd
     JOIN dishes d              ON d.id  = fd.dish_id
     JOIN restaurant_profiles rp ON rp.id = d.restaurant_id
     WHERE fd.user_id = ?
     ORDER BY fd.created_at DESC`,
    [req.user.id]
  );
  return res.json(normalizeRows(rows));
}

// POST /api/favorites/dishes/:id
async function addFavoriteDish(req, res) {
  const { id } = req.params;
  try {
    await pool.query(
      'INSERT INTO favorite_dishes (user_id, dish_id) VALUES (?,?)',
      [req.user.id, id]
    );
    return res.status(201).json({ message: 'Dish added to favorites' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'Already in favorites' });
    }
    throw err;
  }
}

// DELETE /api/favorites/dishes/:id
async function removeFavoriteDish(req, res) {
  const { id } = req.params;
  await pool.query(
    'DELETE FROM favorite_dishes WHERE user_id = ? AND dish_id = ?',
    [req.user.id, id]
  );
  return res.json({ message: 'Dish removed from favorites' });
}

module.exports = {
  getFavoriteRestaurants, addFavoriteRestaurant, removeFavoriteRestaurant,
  getFavoriteDishes,      addFavoriteDish,       removeFavoriteDish,
};
