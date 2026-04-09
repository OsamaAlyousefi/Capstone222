import axios from 'axios';

import { jobsQueryCache, matchScoreCache } from '../services/cache.js';
import { analyzeCvText } from '../services/gemini.js';
import { extractPdfText } from '../services/pdfParser.js';
import {
  buildCvStoragePath,
  createPublicCvUrl,
  CV_BUCKET,
  supabaseAdmin
} from '../services/supabase.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { badRequest, notFound } from '../utils/httpError.js';

const runAnalysisAndPersist = async ({ userId, cvText, cvUrl }) => {
  const analysis = await analyzeCvText(cvText);

  await supabaseAdmin.from('cv_suggestions').delete().eq('user_id', userId);

  if (Array.isArray(analysis.suggestions) && analysis.suggestions.length > 0) {
    await supabaseAdmin.from('cv_suggestions').insert(
      analysis.suggestions.map((item) => ({
        user_id: userId,
        type: item.type,
        suggestion: item.suggestion,
        priority: item.priority
      }))
    );
  }

  const { data: updatedProfile, error } = await supabaseAdmin
    .from('profiles')
    .update({
      cv_url: cvUrl,
      cv_text: cvText,
      cv_score: Math.round(
        (
          Number(analysis.completeness_score ?? 0) +
          Number(analysis.ats_score ?? 0) +
          Number(analysis.alignment_score ?? 0)
        ) / 3
      ),
      cv_health: analysis.health_label,
      cv_completeness: analysis.completeness_score,
      cv_ats_score: analysis.ats_score,
      cv_alignment_score: analysis.alignment_score,
      cv_last_analyzed_at: new Date().toISOString()
    })
    .eq('id', userId)
    .select('*')
    .single();

  if (error) {
    throw badRequest(error.message, error);
  }

  const { data: suggestions } = await supabaseAdmin
    .from('cv_suggestions')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  return {
    profile: updatedProfile,
    suggestions: suggestions ?? []
  };
};

const getCurrentProfile = async (userId) => {
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

const extractStoragePathFromPublicUrl = (publicUrl) => {
  if (!publicUrl) {
    return null;
  }

  const marker = `/storage/v1/object/public/${CV_BUCKET}/`;
  const index = publicUrl.indexOf(marker);
  if (index === -1) {
    return null;
  }

  return publicUrl.slice(index + marker.length);
};

export const uploadCv = asyncHandler(async (req, res) => {
  if (!req.file) {
    throw badRequest('Attach a PDF file in form-data under the "file" field');
  }

  if (req.file.mimetype !== 'application/pdf') {
    throw badRequest('Only PDF uploads are supported by this endpoint');
  }

  const profile = await getCurrentProfile(req.user.id);
  if (profile.cv_url) {
    await supabaseAdmin.from('cv_history').insert({
      user_id: req.user.id,
      cv_url: profile.cv_url,
      cv_score: profile.cv_score
    });
  }

  const storagePath = buildCvStoragePath(req.user.id, req.file.originalname);
  const { error: uploadError } = await supabaseAdmin.storage
    .from(CV_BUCKET)
    .upload(storagePath, req.file.buffer, {
      contentType: req.file.mimetype,
      upsert: false
    });

  if (uploadError) {
    throw badRequest(uploadError.message, uploadError);
  }

  const cvUrl = createPublicCvUrl(storagePath);
  const cvText = await extractPdfText(req.file.buffer);
  const result = await runAnalysisAndPersist({
    userId: req.user.id,
    cvText,
    cvUrl
  });
  matchScoreCache.flushAll();
  jobsQueryCache.flushAll();

  res.status(201).json({
    cv_url: result.profile.cv_url,
    cv_score: result.profile.cv_score,
    cv_health: result.profile.cv_health,
    cv_completeness: result.profile.cv_completeness,
    cv_ats_score: result.profile.cv_ats_score,
    cv_alignment_score: result.profile.cv_alignment_score,
    suggestions: result.suggestions
  });
});

export const getCv = asyncHandler(async (req, res) => {
  const profile = await getCurrentProfile(req.user.id);
  const { data: suggestions, error } = await supabaseAdmin
    .from('cv_suggestions')
    .select('*')
    .eq('user_id', req.user.id)
    .order('created_at', { ascending: false });

  if (error) {
    throw badRequest(error.message, error);
  }

  res.json({
    cv_url: profile.cv_url,
    cv_score: profile.cv_score,
    cv_health: profile.cv_health,
    cv_completeness: profile.cv_completeness,
    cv_ats_score: profile.cv_ats_score,
    cv_alignment_score: profile.cv_alignment_score,
    cv_last_analyzed_at: profile.cv_last_analyzed_at,
    suggestions: suggestions ?? []
  });
});

export const analyzeExistingCv = asyncHandler(async (req, res) => {
  const profile = await getCurrentProfile(req.user.id);
  if (!profile.cv_text) {
    throw badRequest('Upload a CV before requesting analysis');
  }

  const result = await runAnalysisAndPersist({
    userId: req.user.id,
    cvText: profile.cv_text,
    cvUrl: profile.cv_url
  });
  matchScoreCache.flushAll();
  jobsQueryCache.flushAll();

  res.json({
    cv_score: result.profile.cv_score,
    cv_health: result.profile.cv_health,
    cv_completeness: result.profile.cv_completeness,
    cv_ats_score: result.profile.cv_ats_score,
    cv_alignment_score: result.profile.cv_alignment_score,
    suggestions: result.suggestions
  });
});

export const deleteCv = asyncHandler(async (req, res) => {
  const profile = await getCurrentProfile(req.user.id);
  const storagePath = extractStoragePathFromPublicUrl(profile.cv_url);

  if (storagePath) {
    await supabaseAdmin.storage.from(CV_BUCKET).remove([storagePath]);
  }

  await supabaseAdmin.from('cv_suggestions').delete().eq('user_id', req.user.id);

  const { error } = await supabaseAdmin
    .from('profiles')
    .update({
      cv_url: null,
      cv_text: null,
      cv_score: null,
      cv_health: null,
      cv_completeness: null,
      cv_ats_score: null,
      cv_alignment_score: null,
      cv_last_analyzed_at: null
    })
    .eq('id', req.user.id);

  if (error) {
    throw badRequest(error.message, error);
  }
  matchScoreCache.flushAll();
  jobsQueryCache.flushAll();

  res.json({
    success: true,
    message: 'CV removed successfully'
  });
});

export const getCvHistory = asyncHandler(async (req, res) => {
  const { data, error } = await supabaseAdmin
    .from('cv_history')
    .select('*')
    .eq('user_id', req.user.id)
    .order('uploaded_at', { ascending: false });

  if (error) {
    throw badRequest(error.message, error);
  }

  res.json(data ?? []);
});

export const restoreCvHistory = asyncHandler(async (req, res) => {
  const { historyId } = req.params;

  const { data: history, error } = await supabaseAdmin
    .from('cv_history')
    .select('*')
    .eq('id', historyId)
    .eq('user_id', req.user.id)
    .maybeSingle();

  if (error) {
    throw badRequest(error.message, error);
  }
  if (!history) {
    throw notFound('CV history item not found');
  }

  const response = await axios.get(history.cv_url, {
    responseType: 'arraybuffer'
  });
  const buffer = Buffer.from(response.data);
  const cvText = await extractPdfText(buffer);

  const result = await runAnalysisAndPersist({
    userId: req.user.id,
    cvText,
    cvUrl: history.cv_url
  });
  matchScoreCache.flushAll();
  jobsQueryCache.flushAll();

  res.json({
    restored: true,
    cv_url: result.profile.cv_url,
    cv_score: result.profile.cv_score,
    cv_health: result.profile.cv_health,
    suggestions: result.suggestions
  });
});
