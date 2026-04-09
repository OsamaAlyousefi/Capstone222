import { sendPushNotification } from '../services/fcm.js';
import { buildApplicationReceivedMessage } from '../services/inboxSimulator.js';
import { jobsQueryCache } from '../services/cache.js';
import { supabaseAdmin } from '../services/supabase.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { badRequest, notFound } from '../utils/httpError.js';

const getUserProfile = async (userId) => {
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

const getApplicationsWithJobs = async (userId, status) => {
  let query = supabaseAdmin
    .from('applications')
    .select('*')
    .eq('user_id', userId)
    .order('applied_at', { ascending: false });

  if (status) {
    query = query.eq('status', status);
  }

  const { data: applications, error } = await query;
  if (error) {
    throw badRequest(error.message, error);
  }

  const jobIds = (applications ?? []).map((item) => item.job_id);
  const { data: jobs, error: jobsError } = await supabaseAdmin
    .from('jobs')
    .select('*')
    .in('id', jobIds.length > 0 ? jobIds : ['00000000-0000-0000-0000-000000000000']);

  if (jobsError) {
    throw badRequest(jobsError.message, jobsError);
  }

  const jobsMap = new Map((jobs ?? []).map((job) => [job.id, job]));
  return (applications ?? []).map((application) => ({
    ...application,
    job: jobsMap.get(application.job_id) ?? null
  }));
};

export const getApplications = asyncHandler(async (req, res) => {
  const data = await getApplicationsWithJobs(req.user.id, req.query.status);
  res.json(data);
});

export const createApplication = asyncHandler(async (req, res) => {
  const { job_id: jobId } = req.body ?? {};
  if (!jobId) {
    throw badRequest('job_id is required');
  }

  const { data: job, error: jobError } = await supabaseAdmin
    .from('jobs')
    .select('*')
    .eq('id', jobId)
    .maybeSingle();

  if (jobError) {
    throw badRequest(jobError.message, jobError);
  }
  if (!job) {
    throw notFound('Job not found');
  }

  const { data: application, error } = await supabaseAdmin
    .from('applications')
    .insert({
      user_id: req.user.id,
      job_id: jobId,
      source: 'easy_apply'
    })
    .select('*')
    .single();

  if (error) {
    throw badRequest(error.message, error);
  }

  const profile = await getUserProfile(req.user.id);
  const { data: currentInteraction } = await supabaseAdmin
    .from('user_job_interactions')
    .select('*')
    .eq('user_id', req.user.id)
    .eq('job_id', jobId)
    .maybeSingle();

  await supabaseAdmin.from('user_job_interactions').upsert(
    {
      user_id: req.user.id,
      job_id: jobId,
      action: 'applied',
      match_score: currentInteraction?.match_score ?? null,
      match_label: currentInteraction?.match_label ?? null,
      match_reason: currentInteraction?.match_reason ?? null
    },
    { onConflict: 'user_id,job_id' }
  );

  const simulatedMessage = buildApplicationReceivedMessage({
    fullName: profile.full_name,
    jobTitle: job.title,
    company: job.company
  });

  const { data: inboxMessage, error: inboxError } = await supabaseAdmin
    .from('inbox_messages')
    .insert({
      user_id: req.user.id,
      application_id: application.id,
      ...simulatedMessage
    })
    .select('*')
    .single();

  if (inboxError) {
    throw badRequest(inboxError.message, inboxError);
  }

  await sendPushNotification(
    profile.fcm_token,
    'Application sent',
    `Application sent to ${job.company}`,
    { applicationId: application.id, jobId }
  );
  jobsQueryCache.flushAll();

  res.status(201).json({
    application: {
      ...application,
      job
    },
    inbox_message: inboxMessage
  });
});

export const updateApplication = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const updates = {};

  if (req.body?.status) {
    updates.status = req.body.status;
  }
  if (req.body?.notes !== undefined) {
    updates.notes = req.body.notes;
  }

  if (Object.keys(updates).length === 0) {
    throw badRequest('Provide status and/or notes to update the application');
  }

  const { data, error } = await supabaseAdmin
    .from('applications')
    .update(updates)
    .eq('id', id)
    .eq('user_id', req.user.id)
    .select('*')
    .maybeSingle();

  if (error) {
    throw badRequest(error.message, error);
  }
  if (!data) {
    throw notFound('Application not found');
  }
  jobsQueryCache.flushAll();

  res.json(data);
});

export const withdrawApplication = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { data, error } = await supabaseAdmin
    .from('applications')
    .update({ status: 'withdrawn' })
    .eq('id', id)
    .eq('user_id', req.user.id)
    .select('*')
    .maybeSingle();

  if (error) {
    throw badRequest(error.message, error);
  }
  if (!data) {
    throw notFound('Application not found');
  }
  jobsQueryCache.flushAll();

  res.json({
    success: true,
    application: data
  });
});
