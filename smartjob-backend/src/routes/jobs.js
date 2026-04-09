import { Router } from 'express';

import {
  getJobById,
  getJobs,
  getKeywordGap,
  getSavedJobs,
  interactWithJob
} from '../controllers/jobsController.js';

const router = Router();

router.get('/saved', getSavedJobs);
router.get('/keyword-gap', getKeywordGap);
router.get('/', getJobs);
router.get('/:id', getJobById);
router.post('/:id/interact', interactWithJob);

export default router;
