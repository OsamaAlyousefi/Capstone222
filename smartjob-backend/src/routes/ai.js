import { Router } from 'express';

import {
  chatAboutCv,
  getMatchScore,
  keywordGap,
  rewriteSection
} from '../controllers/aiController.js';

const router = Router();

router.post('/match-score', getMatchScore);
router.post('/cv-chat', chatAboutCv);
router.post('/improve-section', rewriteSection);
router.post('/keyword-gap', keywordGap);

export default router;
