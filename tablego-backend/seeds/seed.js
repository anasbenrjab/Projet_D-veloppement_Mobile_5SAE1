/**
 * TableGo - seed script
 * Usage:  node seeds/seed.js  /  npm run seed
 *
 * Idempotent: clears related rows before re-inserting (FK-safe order).
 * Generates bcrypt hashes at runtime.
 */

require('dotenv').config();
const mysql  = require('mysql2/promise');
const bcrypt = require('bcrypt');

const SALT_ROUNDS = 10;

const PHOTOS = {
  gourmet: ['https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800'],
  burger:  ['https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800'],
  sushi:   ['https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800'],
};

const DISH_PHOTOS = {
  soupe:   'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600',
  poulet:  'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=600',
  smash:   'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600',
  crispy:  'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=600',
  sashimi: 'https://images.unsplash.com/photo-1611143669185-af224c5e3252?w=600',
};

const hoursGourmet = {
  mon: { open: '11:00', close: '23:00' }, tue: { open: '11:00', close: '23:00' },
  wed: { open: '11:00', close: '23:00' }, thu: { open: '11:00', close: '23:00' },
  fri: { open: '11:00', close: '00:00' }, sat: { open: '10:00', close: '00:00' },
  sun: { open: '10:00', close: '22:00' },
};
const hoursBurger = {
  mon: { open: '10:00', close: '23:00' }, tue: { open: '10:00', close: '23:00' },
  wed: { open: '10:00', close: '23:00' }, thu: { open: '10:00', close: '23:00' },
  fri: { open: '10:00', close: '01:00' }, sat: { open: '10:00', close: '01:00' },
  sun: { open: '11:00', close: '22:00' },
};
const hoursSushi = {
  mon: { open: '12:00', close: '22:00' }, tue: { open: '12:00', close: '22:00' },
  wed: { open: '12:00', close: '22:00' }, thu: { open: '12:00', close: '22:00' },
  fri: { open: '12:00', close: '23:00' }, sat: { open: '11:00', close: '23:00' },
  sun: { open: '11:00', close: '21:00' },
};

async function main() {
  const conn = await mysql.createConnection({
    host:               process.env.DB_HOST     || 'localhost',
    user:               process.env.DB_USER     || 'root',
    password:           process.env.DB_PASSWORD || '',
    database:           process.env.DB_NAME     || 'tablego',
    multipleStatements: true,
  });

  try {
    console.log('Hashing password...');
    const hash = bcrypt.hashSync('password123', SALT_ROUNDS);

    console.log('Clearing existing seed data...');
    await conn.query(`
      DELETE FROM order_history         WHERE user_id IN (1,2,3,4);
      DELETE FROM favorite_dishes       WHERE user_id IN (1,2,3,4);
      DELETE FROM favorite_restaurants  WHERE user_id IN (1,2,3,4);
      DELETE FROM dishes                WHERE id      IN (1,2,3,4,5);
      DELETE FROM restaurant_profiles   WHERE user_id IN (2,3,4);
      DELETE FROM client_profiles       WHERE user_id IN (1);
      DELETE FROM users                 WHERE id      IN (1,2,3,4);
    `);

    console.log('Inserting users...');
    await conn.query(
      `INSERT INTO users (id, email, password_hash, user_type) VALUES
       (1, 'client@test.com',      ?, 'client'),
       (2, 'resto@test.com',       ?, 'restaurant'),
       (3, 'burgerking@test.com',  ?, 'restaurant'),
       (4, 'sushi@test.com',       ?, 'restaurant')`,
      [hash, hash, hash, hash]
    );

    console.log('Inserting client profile...');
    await conn.query(
      `INSERT INTO client_profiles (user_id, full_name, phone, dietary_preferences, allergies) VALUES (1, 'Alice Dupont', '+33 6 12 34 56 78', ?, ?)`,
      [JSON.stringify(['halal', 'vegetarian']), JSON.stringify(['peanuts'])]
    );

    console.log('Inserting restaurant profiles...');
    await conn.query(
      `INSERT INTO restaurant_profiles (user_id, name, address, latitude, longitude, opening_hours, cuisine_type, photos, description) VALUES
        (2, 'Le Gourmet Parisien', '12 Rue de Rivoli, Paris 75001', 48.85600, 2.34200, ?, 'French', ?, 'Authentic Parisian cuisine in the heart of Paris.'),
        (3, 'Burger Palace', '45 Avenue des Champs-Elysees, Paris 75008', 48.87320, 2.29540, ?, 'American', ?, 'Best smash burgers in Paris.'),
        (4, 'Tokyo Sushi Bar', '8 Rue Saint-Anne, Paris 75001', 48.86500, 2.33800, ?, 'Japanese', ?, 'Fresh sushi and ramen from Tokyo recipes.')`,
      [
        JSON.stringify(hoursGourmet), JSON.stringify(PHOTOS.gourmet),
        JSON.stringify(hoursBurger),  JSON.stringify(PHOTOS.burger),
        JSON.stringify(hoursSushi),   JSON.stringify(PHOTOS.sushi),
      ]
    );

    console.log('Resolving restaurant profile IDs...');
    const [rpRows] = await conn.query(
      'SELECT id, user_id FROM restaurant_profiles WHERE user_id IN (2,3,4) ORDER BY user_id'
    );
    const rpId = {};
    for (const r of rpRows) rpId[r.user_id] = r.id;
    console.log('  resto=' + rpId[2] + '  burger=' + rpId[3] + '  sushi=' + rpId[4]);

    console.log('Inserting dishes...');
    await conn.query(
      `INSERT INTO dishes (id, restaurant_id, name, description, price, photo_url, tags) VALUES
       (1, ?, 'Soupe a l''oignon',    'Classic French onion soup with gruyere crouton', 12.50, ?, ?),
       (2, ?, 'Poulet roti',           'Oven-roasted chicken with seasonal vegetables',  18.90, ?, ?),
       (3, ?, 'Smash Burger Classic',  'Double smash patty, cheddar, pickles, house sauce', 14.00, ?, ?),
       (4, ?, 'Crispy Chicken Burger', 'Crispy fried chicken, coleslaw, sriracha mayo',  13.50, ?, ?),
       (5, ?, 'Salmon Sashimi (8 pcs)','Premium Atlantic salmon, fresh wasabi',          16.00, ?, ?)`,
      [
        rpId[2], DISH_PHOTOS.soupe,   JSON.stringify(["vegetarian"]),
        rpId[2], DISH_PHOTOS.poulet,  JSON.stringify(["halal"]),
        rpId[3], DISH_PHOTOS.smash,   JSON.stringify([]),
        rpId[3], DISH_PHOTOS.crispy,  JSON.stringify(["halal"]),
        rpId[4], DISH_PHOTOS.sashimi, JSON.stringify([]),
      ]
    );

    console.log('Inserting favourite restaurants...');
    await conn.query('INSERT INTO favorite_restaurants (user_id, restaurant_id) VALUES (1, ?), (1, ?)', [rpId[2], rpId[4]]);

    console.log('Inserting favourite dishes...');
    await conn.query('INSERT INTO favorite_dishes (user_id, dish_id) VALUES (1, 4), (1, 5)');

    console.log('Inserting order history...');
    await conn.query(
      `INSERT INTO order_history (user_id, restaurant_id, dish_id) VALUES (1, ?, 1), (1, ?, 2), (1, ?, 5), (1, ?, 3)`,
      [rpId[2], rpId[2], rpId[4], rpId[3]]
    );

    console.log('');
    console.log('Seed complete!');
    console.log('  client@test.com      / password123  (client)');
    console.log('  resto@test.com       / password123  (restaurant)');
    console.log('  burgerking@test.com  / password123  (restaurant)');
    console.log('  sushi@test.com       / password123  (restaurant)');

  } finally {
    await conn.end();
  }
}

main().catch(err => {
  console.error('Seed failed:', err.message);
  process.exit(1);
});