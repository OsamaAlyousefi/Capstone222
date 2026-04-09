import cron from 'node-cron';

import { fetchAdzunaJobs, isAdzunaConfigured } from '../services/adzuna.js';
import { supabaseAdmin } from '../services/supabase.js';
import { expireOldJobs } from './expireJobs.js';

const uniqueCombos = (profiles) => {
  const seen = new Set();
  const combos = [];

  for (const profile of profiles ?? []) {
    for (const role of profile.desired_roles ?? []) {
      for (const location of profile.preferred_locations ?? []) {
        const key = `${role}::${location}`;
        if (!seen.has(key)) {
          seen.add(key);
          combos.push({ role, location });
        }
      }
    }
  }

  return combos.slice(0, 10);
};

export const syncJobs = async () => {
  if (!isAdzunaConfigured) {
    console.log('Skipping Adzuna sync because credentials are not configured.');
    return;
  }

  const { data: profiles, error } = await supabaseAdmin
    .from('profiles')
    .select('desired_roles, preferred_locations');

  if (error) {
    console.error('Failed to load profiles for job sync:', error);
    return;
  }

  const combos = uniqueCombos(profiles);
  for (const combo of combos) {
    try {
      const jobs = await fetchAdzunaJobs(combo);
      if (jobs.length > 0) {
        const { error: upsertError } = await supabaseAdmin
          .from('jobs')
          .upsert(jobs, { onConflict: 'external_id' });

        if (upsertError) {
          console.error('Failed to upsert synced jobs:', upsertError);
        }
      }
    } catch (syncError) {
      console.error(`Failed to sync jobs for ${combo.role} in ${combo.location}:`, syncError);
    }
  }

  await expireOldJobs();
};

export const registerSyncJobsJob = () => {
  cron.schedule('0 */6 * * *', syncJobs);
};
