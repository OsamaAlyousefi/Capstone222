import multer from 'multer';
import { Router } from 'express';

import {
  analyzeExistingCv,
  deleteCv,
  getCv,
  getCvHistory,
  restoreCvHistory,
  uploadCv
} from '../controllers/cvController.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024
  }
});

const router = Router();

router.post('/upload', upload.single('file'), uploadCv);
router.get('/history', getCvHistory);
router.post('/restore/:historyId', restoreCvHistory);
router.get('/', getCv);
router.post('/analyze', analyzeExistingCv);
router.delete('/', deleteCv);

export default router;
