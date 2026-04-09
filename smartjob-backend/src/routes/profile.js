import { Router } from 'express';

import {
  deleteProfile,
  getProfile,
  updateProfile
} from '../controllers/profileController.js';

const router = Router();

router.get('/', getProfile);
router.put('/', updateProfile);
router.delete('/', deleteProfile);

export default router;
