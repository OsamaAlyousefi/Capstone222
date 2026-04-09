import { Router } from 'express';

import {
  createApplication,
  getApplications,
  updateApplication,
  withdrawApplication
} from '../controllers/applicationsController.js';

const router = Router();

router.get('/', getApplications);
router.post('/', createApplication);
router.put('/:id', updateApplication);
router.delete('/:id', withdrawApplication);

export default router;
