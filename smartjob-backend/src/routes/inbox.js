import { Router } from 'express';

import {
  deleteInboxMessage,
  getInboxMessages,
  markInboxMessageRead,
  simulateInboxMessage
} from '../controllers/inboxController.js';

const router = Router();

router.get('/', getInboxMessages);
router.put('/:id/read', markInboxMessageRead);
router.delete('/:id', deleteInboxMessage);
router.post('/simulate', simulateInboxMessage);

export default router;
