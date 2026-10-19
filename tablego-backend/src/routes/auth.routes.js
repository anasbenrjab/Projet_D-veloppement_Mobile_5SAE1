const router = require('express').Router();
const auth   = require('../middleware/auth');
const ctrl   = require('../controllers/auth.controller');

router.post('/register',         ctrl.register);
router.post('/login',            ctrl.login);
router.post('/forgot-password',  ctrl.forgotPassword);
router.post('/reset-password',   ctrl.resetPassword);
router.put('/change-password',   auth, ctrl.changePassword);
router.delete('/account',        auth, ctrl.deleteAccount);

module.exports = router;
