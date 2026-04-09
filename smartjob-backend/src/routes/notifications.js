import { Router } from 'express';

import {
  getNotificationSettings,
  registerNotificationToken,
  updateNotificationSettings
} from '../controllers/notificationsController.js';

const router = Router();

router.get('/settings', getNotificationSettings);
router.put('/settings', updateNotificationSettings);
router.post('/register-token', registerNotificationToken);

export default router;
