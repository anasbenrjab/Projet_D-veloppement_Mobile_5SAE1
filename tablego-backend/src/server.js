require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const path    = require('path');

const authRoutes            = require('./routes/auth.routes');
const profileRoutes         = require('./routes/profile.routes');
const favoritesRoutes       = require('./routes/favorites.routes');
const recommendationsRoutes = require('./routes/recommendations.routes');

const app  = express();
const PORT = process.env.PORT || 3000;

// ─── Middleware ───────────────────────────────────────────────────────────────
app.use(cors({ origin: '*' }));        // open CORS for dev
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ─── Static uploads ──────────────────────────────────────────────────────────
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ─── Routes ──────────────────────────────────────────────────────────────────
app.use('/api/auth',            authRoutes);
app.use('/api/profile',         profileRoutes);
app.use('/api/favorites',       favoritesRoutes);
app.use('/api/recommendations', recommendationsRoutes);

// ─── Health check ────────────────────────────────────────────────────────────
app.get('/api/health', (req, res) => res.json({ status: 'ok', timestamp: new Date() }));

// ─── 404 handler ─────────────────────────────────────────────────────────────
app.use((req, res) => res.status(404).json({ message: 'Route not found' }));

// ─── Error handler ───────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ message: err.message || 'Internal server error' });
});

app.listen(PORT, () => console.log(`TableGo API running on port ${PORT}`));

module.exports = app;
