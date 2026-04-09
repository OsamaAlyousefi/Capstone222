import { supabaseAdmin } from '../services/supabase.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { badRequest, notFound } from '../utils/httpError.js';

const editableFields = [
  'full_name',
  'title',
  'phone',
  'location',
  'linkedin_url',
  'github_url',
  'website_url',
  'avatar_url',
  'desired_roles',
  'employment_types',
  'work_modes',
  'preferred_locations',
  'skills',
  'alert_frequency',
  'push_alerts_enabled',
  'email_alerts_enabled',
  'fcm_token'
];

export const getProfile = asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('profiles')
    .select('*')
    .eq('id', req.user.id)
    .maybeSingle();

  if (error) {
    throw badRequest(error.message, error);
  }
  if (!data) {
    throw notFound('Profile not found');
  }

  res.json(data);
});

export const updateProfile = asyncHandler(async (req, res) => {
  const updates = Object.fromEntries(
    Object.entries(req.body ?? {}).filter(([key]) => editableFields.includes(key))
  );

  if (Object.keys(updates).length === 0) {
    throw badRequest('No valid profile fields were provided');
  }

  const { data, error } = await supabaseAdmin
    .from('profiles')
    .update(updates)
    .eq('id', req.user.id)
    .select('*')
    .single();

  if (error) {
    throw badRequest(error.message, error);
  }

  res.json(data);
});

export const deleteProfile = asyncHandler(async (req, res) => {
  const confirmation = req.body?.confirmation;
  if (confirmation !== 'DELETE') {
    throw badRequest('Send confirmation=DELETE to remove the account');
  }

  const { error } = await supabaseAdmin.auth.admin.deleteUser(req.user.id);
  if (error) {
    throw badRequest(error.message, error);
  }

  res.json({
    success: true,
    message: 'Account deleted successfully'
  });
});
