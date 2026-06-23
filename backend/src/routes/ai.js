const express = require('express');
const router = express.Router();
const AIController = require('../controllers/aiController');

// No auth middleware required for local proxy mode
router.post('/chat', AIController.chat);
router.post('/voice-parse', AIController.parseVoice);
router.post('/ocr-upload', AIController.parseReceipt);

module.exports = router;
