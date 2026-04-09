import { createClient } from '@supabase/supabase-js';

import { config, requireConfig } from '../config.js';
import { HttpError } from '../utils/httpError.js';

requireConfig('supabaseUrl', 'supabaseServiceRoleKey');

export const CV_BUCKET = 'cvs';

export const supabaseAdmin = createClient(
  config.supabaseUrl,
  config.supabaseServiceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
);

export const ensureSingle = async (queryPromise, notFoundMessage) => {
  const { data, error } = await queryPromise;
  if (error) {
    throw new HttpError(400, error.message, error);
  }
  if (!data) {
    throw new HttpError(404, notFoundMessage);
  }
  return data;
};

export const ensureSuccess = async (queryPromise) => {
  const { data, error } = await queryPromise;
  if (error) {
    throw new HttpError(400, error.message, error);
  }
  return data;
};

export const createPublicCvUrl = (storagePath) => {
  const { data } = supabaseAdmin.storage.from(CV_BUCKET).getPublicUrl(storagePath);
  return data.publicUrl;
};

export const sanitizeFileName = (fileName) => {
  const normalized = fileName.trim().replace(/[^a-zA-Z0-9._-]+/g, '_');
  return normalized || 'resume.pdf';
};

export const buildCvStoragePath = (userId, fileName) => {
  return `${userId}/${Date.now()}_${sanitizeFileName(fileName)}`;
};

export const buildInboxAlias = (userId) => {
  const compact = userId.replace(/-/g, '').slice(0, 12);
  return `${compact}@smartjob.app`;
};
