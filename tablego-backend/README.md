# TableGo Backend

Node.js + Express + MySQL2 REST API for the TableGo app.

## Setup

1. Create DB schema:
   mysql -u root -p < migrations/schema.sql

2. Seed data (generates bcrypt hashes at runtime):
   npm run seed

3. Configure environment:
   cp .env.example .env   # edit DB_PASSWORD and JWT_SECRET

4. Install dependencies:
   npm install

5. Start dev server:
   npm run dev

## Scripts

| Command       | Description                    |
|---------------|--------------------------------|
| npm run dev   | Start with nodemon (hot-reload)|
| npm start     | Start without hot-reload       |
| npm run seed  | Clear and re-seed the database |

## Test Credentials

| Role       | Email                | Password    |
|------------|----------------------|-------------|
| Client     | client@test.com      | password123 |
| Restaurant | resto@test.com       | password123 |
| Restaurant | burgerking@test.com  | password123 |
| Restaurant | sushi@test.com       | password123 |

## Endpoints

### Auth
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/forgot-password
POST   /api/auth/reset-password
PUT    /api/auth/change-password   (auth)
DELETE /api/auth/account           (auth)

### Profile
GET    /api/profile/me             (auth)
PUT    /api/profile/client         (auth)
PUT    /api/profile/restaurant     (auth)
POST   /api/profile/upload-photo   (auth, multipart)

### Favorites
GET    /api/favorites/restaurants        (auth)
POST   /api/favorites/restaurants/:id   (auth)
DELETE /api/favorites/restaurants/:id   (auth)
GET    /api/favorites/dishes             (auth)
POST   /api/favorites/dishes/:id        (auth)
DELETE /api/favorites/dishes/:id        (auth)

### Recommendations
GET    /api/recommendations             (auth)