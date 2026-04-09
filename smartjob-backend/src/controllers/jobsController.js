import { analyzeKeywordGap, scoreJobMatch } from '../services/gemini.js';
import { jobsQueryCache } from '../services/cache.js';
import { supabaseAdmin } from '../services/supabase.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { badRequest, notFound } from '../utils/httpError.js';

const listToLower = (value) => (value ?? []).map((item) => String(item).toLowerCase());

const getProfile = async (userId) => {
  const { data, error } = await supabaseAdmin
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) {
    throw badRequest(error.message, error);
  }

  return data;
};

const getInteractionsMap = async (userId, jobIds) => {
  if (jobIds.length === 0) {
    return new Map();
  }

  const { data, error } = await supabaseAdmin
    .from('user_job_interactions')
    .select('*')
    .eq('user_id', userId)
    .in('job_id', jobIds);

  if (error) {
    throw badRequest(error.message, error);
  }

  return new Map((data ?? []).map((item) => [item.job_id, item]));
};

const upsertInteractionScore = async ({
  userId,
  jobId,
  action,
  score,
  label,
  reason
}) => {
  const { error } = await supabaseAdmin.from('user_job_interactions').upsert(
    {
      user_id: userId,
      job_id: jobId,
      action,
      match_score: score,
      match_label: label,
      match_reason: reason
    },
    {
      onConflict: 'user_id,job_id'
    }
  );

  if (error) {
    throw badRequest(error.message, error);
  }
};

const filterJobs = ({ jobs, profile, query, excludedJobIds }) => {
  const preferredLocations = listToLower(profile.preferred_locations);
  const preferredWorkModes = listToLower(profile.work_modes);

  return jobs.filter((job) => {
    if (excludedJobIds.has(job.id)) {
      return false;
    }

    if (query.search) {
      const haystack = `${job.title} ${job.company}`.toLowerCase();
      if (!haystack.includes(String(query.search).toLowerCase())) {
        return false;
      }
    }

    if (query.location && !String(job.location ?? '').toLowerCase().includes(String(query.location).toLowerCase())) {
      return false;
    }

    if (query.work_mode && job.work_mode !== query.work_mode) {
      return false;
    }

    if (query.employment_type && job.employment_type !== query.employment_type) {
      return false;
    }

    if (
      query.salary_min &&
      Number(job.salary_max ?? job.salary_min ?? 0) < Number(query.salary_min)
    ) {
      return false;
    }

    if (
      !query.location &&
      preferredLocations.length > 0 &&
      !preferredLocations.some((location) =>
        String(job.location ?? '').toLowerCase().includes(location)
      )
    ) {
      return false;
    }

    if (
      !query.work_mode &&
      preferredWorkModes.length > 0 &&
      !preferredWorkModes.includes(String(job.work_mode ?? '').toLowerCase())
    ) {
      return false;
    }

    return true;
  });
};

const enrichJobsWithMatches = async ({ userId, profile, jobs, interactionsMap }) => {
  const enriched = [];

  for (const job of jobs) {
    const existing = interactionsMap.get(job.id);
    if (existing?.match_score != null) {
      enriched.push({
        ...job,
        match_score: existing.match_score,
        match_label: existing.match_label,
        match_reason: existing.match_reason,
        user_action: existing.action
      });
      continue;
    }

    const match = await scoreJobMatch({
      profile,
      job,
      weights: profile.user_feed_weights ?? {}
    });

    await upsertInteractionScore({
      userId,
      jobId: job.id,
      action: existing?.action ?? null,
      score: match.match_score,
      label: match.match_label,
      reason: match.reason
    });

    enriched.push({
      ...job,
      match_score: match.match_score,
      match_label: match.match_label,
      match_reason: match.reason,
      user_action: existing?.action ?? null
    });
  }

  return enriched;
};

const updateFeedWeights = async ({ userId, currentWeights, action, job }) => {
  const next = {
    total_interactions: Number(currentWeights?.total_interactions ?? 0) + 1,
    work_mode_bias: {
      Remote: Number(currentWeights?.work_mode_bias?.Remote ?? 0),
      Hybrid: Number(currentWeights?.work_mode_bias?.Hybrid ?? 0),
      'On-site': Number(currentWeights?.work_mode_bias?.['On-site'] ?? 0)
    },
    seniority_bias: {
      junior: Number(currentWeights?.seniority_bias?.junior ?? 0),
      mid: Number(currentWeights?.seniority_bias?.mid ?? 0),
      senior: Number(currentWeights?.seniority_bias?.senior ?? 0)
    }
  };

  const direction = action === 'saved' || action === 'interested' ? 1 : -1;
  if (job.work_mode && next.work_mode_bias[job.work_mode] != null) {
    next.work_mode_bias[job.work_mode] += direction;
  }

  const seniorityKey = /senior|lead|staff/i.test(job.title)
    ? 'senior'
    : /mid/i.test(job.title)
      ? 'mid'
      : 'junior';
  next.seniority_bias[seniorityKey] += direction;

  await supabaseAdmin
    .from('profiles')
    .update({ user_feed_weights: next })
    .eq('id', userId);
};

export const getJobs = asyncHandler(async (req, res) => {
  const page = Math.max(Number.parseInt(req.query.page ?? '1', 10), 1);
  const limit = Math.min(Math.max(Number.parseInt(req.query.limit ?? '20', 10), 1), 50);
  const cacheKey = `jobs:${req.user.id}:${JSON.stringify(req.query)}`;
  const cached = jobsQueryCache.get(cacheKey);

  if (cached) {
    return res.json(cached);
  }

  const profile = await getProfile(req.user.id);
  const { data: jobs, error } = await supabaseAdmin
    .from('jobs')
    .select('*')
    .eq('is_active', true)
    .order('posted_at', { ascending: false, nullsFirst: false })
    .limit(100);

  if (error) {
    throw badRequest(error.message, error);
  }

  const { data: excludedInteractions, error: excludedError } = await supabaseAdmin
    .from('user_job_interactions')
    .select('job_id')
    .eq('user_id', req.user.id)
    .in('action', ['hidden', 'skipped']);

  if (excludedError) {
    throw badRequest(excludedError.message, excludedError);
  }

  const filteredJobs = filterJobs({
    jobs: jobs ?? [],
    profile,
    query: req.query,
    excludedJobIds: new Set((excludedInteractions ?? []).map((item) => item.job_id))
  });

  const interactionsMap = await getInteractionsMap(
    req.user.id,
    filteredJobs.map((job) => job.id)
  );
  const enrichedJobs = await enrichJobsWithMatches({
    userId: req.user.id,
    profile,
    jobs: filteredJobs.slice(0, 40),
    interactionsMap
  });

  enrichedJobs.sort((a, b) => {
    const scoreDiff = Number(b.match_score ?? 0) - Number(a.match_score ?? 0);
    if (scoreDiff !== 0) {
      return scoreDiff;
    }
    return new Date(b.posted_at ?? 0) - new Date(a.posted_at ?? 0);
  });

  const total = enrichedJobs.length;
  const paginatedJobs = enrichedJobs.slice((page - 1) * limit, page * limit);
  const payload = {
    page,
    limit,
    total,
    jobs: paginatedJobs
  };

  jobsQueryCache.set(cacheKey, payload);
  res.json(payload);
});

export const getJobById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { data: job, error } = await supabaseAdmin
    .from('jobs')
    .select('*')
    .eq('id', id)
    .maybeSingle();

  if (error) {
    throw badRequest(error.message, error);
  }
  if (!job) {
    throw notFound('Job not found');
  }

  const profile = await getProfile(req.user.id);
  const interactionsMap = await getInteractionsMap(req.user.id, [id]);
  const [enriched] = await enrichJobsWithMatches({
    userId: req.user.id,
    profile,
    jobs: [job],
    interactionsMap
  });

  res.json(enriched);
});

export const interactWithJob = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { action } = req.body ?? {};
  const allowedActions = ['saved', 'skipped', 'interested', 'hidden', 'applied'];

  if (!allowedActions.includes(action)) {
    throw badRequest(`Action must be one of: ${allowedActions.join(', ')}`);
  }

  const { data: job, error: jobError } = await supabaseAdmin
    .from('jobs')
    .select('*')
    .eq('id', id)
    .single();

  if (jobError) {
    throw badRequest(jobError.message, jobError);
  }

  const interactionsMap = await getInteractionsMap(req.user.id, [id]);
  const existing = interactionsMap.get(id);

  await upsertInteractionScore({
    userId: req.user.id,
    jobId: id,
    action,
    score: existing?.match_score ?? null,
    label: existing?.match_label ?? null,
    reason: existing?.match_reason ?? null
  });

  const profile = await getProfile(req.user.id);
  await updateFeedWeights({
    userId: req.user.id,
    currentWeights: profile.user_feed_weights,
    action,
    job
  });
  jobsQueryCache.flushAll();

  res.json({
    success: true,
    action
  });
});

export const getSavedJobs = asyncHandler(async (req, res) => {
  const { data: interactions, error } = await supabaseAdmin
    .from('user_job_interactions')
    .select('*')
    .eq('user_id', req.user.id)
    .eq('action', 'saved')
    .order('created_at', { ascending: false });

  if (error) {
    throw badRequest(error.message, error);
  }

  const jobIds = (interactions ?? []).map((item) => item.job_id);
  const { data: jobs, error: jobsError } = await supabaseAdmin
    .from('jobs')
    .select('*')
    .in('id', jobIds.length > 0 ? jobIds : ['00000000-0000-0000-0000-000000000000']);

  if (jobsError) {
    throw badRequest(jobsError.message, jobsError);
  }

  const jobsMap = new Map((jobs ?? []).map((job) => [job.id, job]));
  res.json(
    (interactions ?? [])
      .map((item) => ({
        ...jobsMap.get(item.job_id),
        match_score: item.match_score,
        match_label: item.match_label,
        match_reason: item.match_reason,
        saved_at: item.created_at
      }))
      .filter(Boolean)
  );
});

export const getKeywordGap = asyncHandler(async (req, res) => {
  const profile = await getProfile(req.user.id);
  const { data: jobs, error } = await supabaseAdmin
    .from('jobs')
    .select('*')
    .eq('is_active', true)
    .order('posted_at', { ascending: false })
    .limit(50);

  if (error) {
    throw badRequest(error.message, error);
  }

  const relevantJobs = (jobs ?? []).filter((job) => {
    const haystack = `${job.title} ${job.description}`.toLowerCase();
    return (profile.desired_roles ?? []).length === 0
      ? true
      : profile.desired_roles.some((role) =>
          haystack.includes(String(role).toLowerCase())
        );
  });

  const jobMarketText = relevantJobs
    .slice(0, 30)
    .map((job) => `${(job.required_skills ?? []).join(', ')} ${job.description ?? ''}`)
    .join('\n');

  const result = await analyzeKeywordGap({
    candidateSkills: profile.skills ?? [],
    jobMarketText
  });

  res.json(result);
});
