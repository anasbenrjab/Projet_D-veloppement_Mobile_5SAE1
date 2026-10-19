const router = require('express').Router();
const auth   = require('../middleware/auth');
const ctrl   = require('../controllers/recommendations.controller');

router.get('/', auth, ctrl.getRecommendations);

module.exports = router;
