const express = require('express');
const router = express.Router();
// const storyController = require('../controllers/storyController'); // Chưa implement controller
const { authenticate } = require('../middlewares/authMiddleware');

// Tất cả các route bên dưới đều được bảo vệ bởi JWT và RLS
router.use(authenticate);

// Mock endpoints mapping
// router.post('/', storyController.create);
// router.get('/feed', storyController.getFeed);
// router.get('/calendar', storyController.getCalendar);

module.exports = router;
