import app from './app.js';
import { config } from './config.js';
import { registerDigestNotificationJobs } from './jobs/digestNotifs.js';
import { registerExpireJobsJob } from './jobs/expireJobs.js';
import { registerSyncJobsJob } from './jobs/syncJobs.js';

registerSyncJobsJob();
registerExpireJobsJob();
registerDigestNotificationJobs();

app.listen(config.port, () => {
  console.log(`SmartJob backend running on port ${config.port}`);
});
