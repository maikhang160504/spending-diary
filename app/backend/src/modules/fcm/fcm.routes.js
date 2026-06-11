'use strict';

const express = require('express');

const { requireAuth } = require('../../middlewares/auth');
const validate = require('../../middlewares/validate');
const controller = require('./fcm.controller');
const { registerFcmTokenSchema, removeFcmTokenSchema } = require('./fcm.schema');

const router = express.Router();

router.use(requireAuth);

router.post(
  '/token',
  validate({ body: registerFcmTokenSchema }),
  controller.registerToken
);

router.delete(
  '/token',
  validate({ body: removeFcmTokenSchema }),
  controller.removeToken
);

module.exports = router;
