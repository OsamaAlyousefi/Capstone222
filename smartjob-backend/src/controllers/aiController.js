import { analyzeKeywordGap, answerCvChat, improveCvSection, scoreJobMatch } from '../services/gemini.js';
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

export const getMatchScore = asyncHandler(async (req, res) => {
  const { job_id: jobId } = req.body ?? {};
  if (!jobId) {
    throw badRequest('job_id is required');
  }

  const profile = await getProfile(req.user.id);
  const { data: job, error } = await supabaseAdmin
    .from('jobs')
    .select('*')
    .eq('id', jobId)
    .maybeSingle();

  if (error) {
    throw badRequest(error.message, error);
  }
  if (!job) {
    throw notFound('Job not found');
  }

  const result = await scoreJobMatch({
    profile,
    job,
    weights: profile.user_feed_weights ?? {}
  });

  await supabaseAdmin.from('user_job_interactions').upsert(
    {
      user_id: req.user.id,
      job_id: job.id,
      action: null,
      match_score: result.match_score,
      match_label: result.match_label,
      match_reason: result.reason
    },
    { onConflict: 'user_id,job_id' }
  );

  res.json({
    match_score: result.match_score,
    match_label: result.match_label,
    match_reason: result.reason
  });
});

export const chatAboutCv = asyncHandler(async (req, res) => {
  const { message, conversation_history: conversationHistory = [] } = req.body ?? {};
  if (!message) {
    throw badRequest('message is required');
  }

  const profile = await getProfile(req.user.id);
  const reply = await answerCvChat({
    profile,
    message,
    conversationHistory
  });

  res.json({ reply });
});

export const rewriteSection = asyncHandler(async (req, res) => {
  const { section_name: sectionName, section_text: sectionText, target_role: targetRole } =
    req.body ?? {};

  if (!sectionName || !sectionText) {
    throw badRequest('section_name and section_text are required');
  }

  const improvedText = await improveCvSection({
    sectionName,
    sectionText,
    targetRole
  });

  res.json({ improved_text: improvedText });
});

export const keywordGap = asyncHandler(async (req, res) => {
  const profile = await getProfile(req.user.id);
  const { data: jobs, error } = await supabaseAdmin
    .from('jobs')
    .select('required_skills, description, title')
    .eq('is_active', true)
    .order('posted_at', { ascending: false })
    .limit(30);

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

  const result = await analyzeKeywordGap({
    candidateSkills: profile.skills ?? [],
    jobMarketText: relevantJobs
      .map((job) => `${(job.required_skills ?? []).join(', ')} ${job.description ?? ''}`)
      .join('\n')
  });

  res.json(result);
});
