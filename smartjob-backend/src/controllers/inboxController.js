import { sendPushNotification } from '../services/fcm.js';
import { buildSimulatedInboxMessage } from '../services/inboxSimulator.js';
import { jobsQueryCache } from '../services/cache.js';
import { supabaseAdmin } from '../services/supabase.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { badRequest, notFound } from '../utils/httpError.js';

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

export const getInboxMessages = asyncHandler(async (req, res) => {
  let query = supabaseAdmin
    .from('inbox_messages')
    .select('*')
    .eq('user_id', req.user.id)
    .order('received_at', { ascending: false });

  if (req.query.category) {
    query = query.eq('category', req.query.category);
  }
  if (req.query.is_read !== undefined) {
    query = query.eq('is_read', req.query.is_read === 'true');
  }

  const { data, error } = await query;
  if (error) {
    throw badRequest(error.message, error);
  }

  res.json(data ?? []);
});

export const markInboxMessageRead = asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('inbox_messages')
    .update({ is_read: true })
    .eq('id', req.params.id)
    .eq('user_id', req.user.id)
    .select('*')
    .maybeSingle();

  if (error) {
    throw badRequest(error.message, error);
  }
  if (!data) {
    throw notFound('Inbox message not found');
  }

  res.json(data);
});

export const deleteInboxMessage = asyncHandler(async (req, res) => {
  const { error } = await supabaseAdmin
    .from('inbox_messages')
    .delete()
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) {
    throw badRequest(error.message, error);
  }

  res.json({
    success: true
  });
});

export const simulateInboxMessage = asyncHandler(async (req, res) => {
  const { application_id: applicationId, message_type: messageType } = req.body ?? {};
  if (!applicationId || !messageType) {
    throw badRequest('application_id and message_type are required');
  }

  const profile = await getProfile(req.user.id);
  const { data: application, error } = await supabaseAdmin
    .from('applications')
    .select('*')
    .eq('id', applicationId)
    .eq('user_id', req.user.id)
    .maybeSingle();

  if (error) {
    throw badRequest(error.message, error);
  }
  if (!application) {
    throw notFound('Application not found');
  }

  const { data: job, error: jobError } = await supabaseAdmin
    .from('jobs')
    .select('*')
    .eq('id', application.job_id)
    .single();

  if (jobError) {
    throw badRequest(jobError.message, jobError);
  }

  const { message, applicationStatus } = buildSimulatedInboxMessage({
    fullName: profile.full_name,
    jobTitle: job.title,
    company: job.company,
    messageType
  });

  const { data: inboxMessage, error: insertError } = await supabaseAdmin
    .from('inbox_messages')
    .insert({
      user_id: req.user.id,
      application_id: application.id,
      ...message
    })
    .select('*')
    .single();

  if (insertError) {
    throw badRequest(insertError.message, insertError);
  }

  if (applicationStatus) {
    await supabaseAdmin
      .from('applications')
      .update({ status: applicationStatus })
      .eq('id', application.id)
      .eq('user_id', req.user.id);
  }

  await sendPushNotification(
    profile.fcm_token,
    `${job.company} has responded`,
    inboxMessage.subject,
    { applicationId: application.id, category: inboxMessage.category }
  );
  jobsQueryCache.flushAll();

  res.status(201).json({
    message: inboxMessage,
    application_status: applicationStatus ?? application.status
  });
});
