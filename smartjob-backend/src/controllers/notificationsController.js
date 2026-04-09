import { supabaseAdmin } from '../services/supabase.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { badRequest } from '../utils/httpError.js';

export const getNotificationSettings = asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('profiles')
    .select('alert_frequency, push_alerts_enabled, email_alerts_enabled, fcm_token')
    .eq('id', req.user.id)
    .single();

  if (error) {
    throw badRequest(error.message, error);
  }

  res.json(data);
});

export const updateNotificationSettings = asyncHandler(async (req, res) => {
  const updates = {};

  if (req.body?.alert_frequency) {
    updates.alert_frequency = req.body.alert_frequency;
  }
  if (req.body?.push_alerts_enabled !== undefined) {
    updates.push_alerts_enabled = req.body.push_alerts_enabled;
  }
  if (req.body?.email_alerts_enabled !== undefined) {
    updates.email_alerts_enabled = req.body.email_alerts_enabled;
  }

  if (Object.keys(updates).length === 0) {
    throw badRequest('Provide alert_frequency, push_alerts_enabled, or email_alerts_enabled');
  }

  const { data, error } = await supabaseAdmin
    .from('profiles')
    .update(updates)
    .eq('id', req.user.id)
    .select('alert_frequency, push_alerts_enabled, email_alerts_enabled, fcm_token')
    .single();

  if (error) {
    throw badRequest(error.message, error);
  }

  res.json(data);
});

export const registerNotificationToken = asyncHandler(async (req, res) => {
  const { token, platform } = req.body ?? {};
  if (!token || !platform) {
    throw badRequest('token and platform are required');
  }

  const { error: profileError } = await supabaseAdmin
    .from('profiles')
    .update({ fcm_token: token })
    .eq('id', req.user.id);

  if (profileError) {
    throw badRequest(profileError.message, profileError);
  }

  const { data, error } = await supabaseAdmin
    .from('device_tokens')
    .upsert(
      {
        user_id: req.user.id,
        token,
        platform
      },
      { onConflict: 'user_id,token' }
    )
    .select('*');

  if (error) {
    throw badRequest(error.message, error);
  }

  res.status(201).json({
    success: true,
    device_tokens: data ?? []
  });
});
