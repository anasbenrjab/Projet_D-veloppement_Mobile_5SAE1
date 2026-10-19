const pool = require('../config/db');
const { normalizeRows } = require('../utils/normalize');

// GET /api/recommendations
async function getRecommendations(req, res) {
  const userId = req.user.id;

  // 1. Get user dietary preferences (may be string or array from DB)
  const [profileRows] = await pool.query(
    'SELECT dietary_preferences FROM client_profiles WHERE user_id = ?',
    [userId]
  );
  let prefs = profileRows[0]?.dietary_preferences ?? [];
  if (typeof prefs === 'string') {
    try { prefs = JSON.parse(prefs); } catch (_) { prefs = []; }
  }
  if (!Array.isArray(prefs)) prefs = [];

  // 2. Order history frequencies
  const [historyRows] = await pool.query(
    `SELECT restaurant_id, COUNT(*) AS order_count
     FROM order_history WHERE user_id = ?
     GROUP BY restaurant_id`,
    [userId]
  );
  const orderMap = {};
  for (const row of historyRows) {
    orderMap[row.restaurant_id] = Number(row.order_count);
  }

  // 3. Favourite restaurant ids
  const [favRows] = await pool.query(
    'SELECT restaurant_id FROM favorite_restaurants WHERE user_id = ?',
    [userId]
  );
  const favSet = new Set(favRows.map(r => r.restaurant_id));

  // 4. All active restaurants + dishes
  const [restaurants] = await pool.query(
    `SELECT rp.id, rp.name, rp.address, rp.latitude, rp.longitude,
            rp.cuisine_type, rp.photos, rp.description, rp.opening_hours
     FROM restaurant_profiles rp
     JOIN users u ON u.id = rp.user_id AND u.is_active = TRUE`
  );

  const [dishes] = await pool.query(
    `SELECT id, restaurant_id, name, price, photo_url, tags
     FROM dishes WHERE is_available = TRUE`
  );

  // Normalise JSON fields in restaurants and dishes
  const normRestaurants = normalizeRows(restaurants);
  const normDishes      = normalizeRows(dishes);

  // Group dishes by restaurant
  const dishesByRestaurant = {};
  for (const dish of normDishes) {
    if (!dishesByRestaurant[dish.restaurant_id]) dishesByRestaurant[dish.restaurant_id] = [];
    dishesByRestaurant[dish.restaurant_id].push(dish);
  }

  // 5. Score
  const scored = normRestaurants.map(r => {
    let score = 0;
    score += (orderMap[r.id] || 0) * 3;
    if (favSet.has(r.id)) score += 5;

    const rDishes = dishesByRestaurant[r.id] || [];
    for (const dish of rDishes) {
      const tags = Array.isArray(dish.tags) ? dish.tags : [];
      for (const pref of prefs) {
        if (tags.includes(pref)) score += 2;
      }
    }

    return { ...r, score, matching_dishes: rDishes.slice(0, 3) };
  });

  scored.sort((a, b) => b.score - a.score);
  return res.json({ recommendations: scored.slice(0, 10) });
}

module.exports = { getRecommendations };
