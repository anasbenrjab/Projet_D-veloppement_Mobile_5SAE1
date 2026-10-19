const router  = require('express').Router();
const multer  = require('multer');
const path    = require('path');
const auth    = require('../middleware/auth');
const ctrl    = require('../controllers/profile.controller');

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, '../../src/uploads')),
  filename:    (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) cb(null, true);
    else cb(new Error('Only image files are allowed'));
  },
});

router.get('/me',             auth, ctrl.getMe);
router.put('/client',         auth, ctrl.updateClientProfile);
router.put('/restaurant',     auth, ctrl.updateRestaurantProfile);
router.post('/upload-photo',  auth, upload.single('photo'), ctrl.uploadPhoto);

module.exports = router;
