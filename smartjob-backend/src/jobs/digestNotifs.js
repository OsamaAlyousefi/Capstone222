import cron from 'node-cron';

import { sendPushNotification } from '../services/fcm.js';
import { supabaseAdmin } from '../services/supabase.js';

const runDigest = async (frequency, lookbackHours) => {
  const { data: profiles, error } = await supabaseAdmin
    .from('profiles')
    .select('*')
    .eq('push_alerts_enabled', true)
    .eq('alert_frequency', frequency)
    .not('fcm_token', 'is', null);

  if (error) {
    console.error(`Failed to load ${frequency} digest profiles:`, error);
    return;
  }

  const cutoff = new Date(Date.now() - lookbackHours * 60 * 60 * 1000).toISOString();
  const { data: jobs, error: jobsError } = await supabaseAdmin
    .from('jobs')
    .select('*')
    .eq('is_active', true)
    .gte('posted_at', cutoff);

  if (jobsError) {
    console.error(`Failed to load ${frequency} digest jobs:`, jobsError);
    return;
  }

  for (const profile of profiles ?? []) {
    const relevantCount = (jobs ?? []).filter((job) => {
      const haystack = `${job.title} ${job.location}`.toLowerCase();
      const roleHit =
        (profile.desired_roles ?? []).length === 0 ||
        profile.desired_roles.some((role) =>
          haystack.includes(String(role).toLowerCase())
        );
      const locationHit =
        (profile.preferred_locations ?? []).length === 0 ||
        profile.preferred_locations.some((location) =>
          haystack.includes(String(location).toLowerCase())
        );
      return roleHit && locationHit;
    }).length;

    if (relevantCount > 0) {
      await sendPushNotification(
        profile.fcm_token,
        'New jobs for you',
        `${relevantCount} new roles match your profile`
      );
    }
  }
};

export const registerDigestNotificationJobs = () => {
  cron.schedule('0 9 * * *', async () => runDigest('Daily', 24));
  cron.schedule('0 9 * * 1', async () => runDigest('Weekly', 24 * 7));
};
