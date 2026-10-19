const router = require('express').Router();
const auth   = require('../middleware/auth');
const ctrl   = require('../controllers/favorites.controller');

router.get('/restaurants',      auth, ctrl.getFavoriteRestaurants);
router.post('/restaurants/:id', auth, ctrl.addFavoriteRestaurant);
router.delete('/restaurants/:id', auth, ctrl.removeFavoriteRestaurant);

router.get('/dishes',           auth, ctrl.getFavoriteDishes);
router.post('/dishes/:id',      auth, ctrl.addFavoriteDish);
router.delete('/dishes/:id',    auth, ctrl.removeFavoriteDish);

module.exports = router;
