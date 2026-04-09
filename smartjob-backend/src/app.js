import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';

import { config } from './config.js';
import { authMiddleware } from './middleware/auth.js';
import { errorHandler } from './middleware/errorHandler.js';
import { aiLimiter, globalLimiter } from './middleware/rateLimit.js';
import aiRoutes from './routes/ai.js';
import applicationsRoutes from './routes/applications.js';
import cvRoutes from './routes/cv.js';
import inboxRoutes from './routes/inbox.js';
import jobsRoutes from './routes/jobs.js';
import notificationsRoutes from './routes/notifications.js';
import profileRoutes from './routes/profile.js';

const app = express();

app.use(helmet());
app.use(
  cors({
    origin: config.clientOrigin === '*' ? true : config.clientOrigin
  })
);
app.use(express.json({ limit: '4mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan(config.isProduction ? 'combined' : 'dev'));
app.use(globalLimiter);

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'smartjob-backend'
  });
});

app.use('/api/v1/profile', authMiddleware, profileRoutes);
app.use('/api/v1/cv', authMiddleware, cvRoutes);
app.use('/api/v1/jobs', authMiddleware, jobsRoutes);
app.use('/api/v1/applications', authMiddleware, applicationsRoutes);
app.use('/api/v1/inbox', authMiddleware, inboxRoutes);
app.use('/api/v1/notifications', authMiddleware, notificationsRoutes);
app.use('/api/v1/ai', authMiddleware, aiLimiter, aiRoutes);

app.use(errorHandler);

export default app;
