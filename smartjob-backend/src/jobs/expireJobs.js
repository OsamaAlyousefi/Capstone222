import cron from 'node-cron';

import { supabaseAdmin } from '../services/supabase.js';

export const expireOldJobs = async () => {
  const cutoffIso = new Date(
    Date.now() - 30 * 24 * 60 * 60 * 1000
  ).toISOString();

  const { error } = await supabaseAdmin
    .from('jobs')
    .update({ is_active: false })
    .lt('posted_at', cutoffIso);

  if (error) {
    console.error('Failed to expire old jobs:', error);
  }
};

export const registerExpireJobsJob = () => {
  cron.schedule('0 2 * * *', expireOldJobs);
};
