import { GoogleGenAI } from '@google/genai';

import { config } from '../config.js';
import { chatHistoryCache, cvAnalysisCache, matchScoreCache } from './cache.js';

const commonSkillHints = [
  'Flutter',
  'Dart',
  'Firebase',
  'REST APIs',
  'State management',
  'Figma',
  'SQL',
  'JavaScript',
  'TypeScript',
  'React',
  'Node.js',
  'UX research',
  'Wireframing',
  'Design systems',
  'Agile'
];

const gemini = config.geminiApiKey
  ? new GoogleGenAI({ apiKey: config.geminiApiKey })
  : null;

export const isGeminiConfigured = Boolean(gemini);

const average = (values) =>
  Math.round(values.reduce((sum, value) => sum + value, 0) / values.length);

const safeJsonParse = (rawText, fallback) => {
  try {
    return JSON.parse(rawText);
  } catch (_) {
    return fallback;
  }
};

const heuristicCvAnalysis = (cvText) => {
  const normalized = cvText.toLowerCase();
  const completenessSignals = ['experience', 'education', 'skills', 'project'];
  const presentSignals = completenessSignals.filter((signal) =>
    normalized.includes(signal)
  ).length;
  const completeness = Math.min(
    100,
    35 + presentSignals * 15 + Math.min(25, Math.round(cvText.length / 120))
  );
  const ats = Math.min(100, 40 + Math.round(cvText.length / 200));
  const alignment = Math.min(
    100,
    30 +
      commonSkillHints.filter((skill) => normalized.includes(skill.toLowerCase()))
        .length *
        8
  );
  const healthAverage = average([completeness, ats, alignment]);
  const healthLabel =
    healthAverage >= 70 ? 'Good' : healthAverage >= 45 ? 'Fair' : 'Poor';

  const suggestedKeywords = commonSkillHints
    .filter((skill) => !normalized.includes(skill.toLowerCase()))
    .slice(0, 8);

  return {
    completeness_score: completeness,
    ats_score: ats,
    alignment_score: alignment,
    health_label: healthLabel,
    suggested_keywords: suggestedKeywords,
    suggestions: [
      {
        type: 'completeness',
        suggestion: 'Add one stronger experience entry with measurable impact.',
        priority: 'high'
      },
      {
        type: 'ats',
        suggestion: 'Use clearer section headings and concise bullet points.',
        priority: 'medium'
      },
      {
        type: 'alignment',
        suggestion: 'Mirror role-specific language from target job descriptions.',
        priority: 'medium'
      },
      {
        type: 'keyword',
        suggestion: `Consider adding keywords such as ${suggestedKeywords.slice(0, 3).join(', ')}.`,
        priority: 'high'
      }
    ]
  };
};

const heuristicMatch = ({ profile, job }) => {
  const haystack =
    `${job.title} ${job.description} ${(job.required_skills ?? []).join(' ')}`.toLowerCase();
  const skills = (profile.skills ?? []).map((skill) => skill.toLowerCase());
  const hits = skills.filter((skill) => haystack.includes(skill)).length;
  const desiredRoleHit = (profile.desired_roles ?? []).some((role) =>
    haystack.includes(String(role).toLowerCase())
  );
  const score = Math.min(98, 35 + hits * 10 + (desiredRoleHit ? 15 : 0));

  return {
    match_score: score,
    match_label:
      score >= 85
        ? 'Excellent match'
        : score >= 70
          ? 'Strong match'
          : score >= 50
            ? 'Good match'
            : 'Low match',
    reason:
      hits > 0
        ? `The role overlaps with ${hits} of your listed skills and target job signals.`
        : 'The role is relevant, but your profile needs stronger overlap with the posted skills.'
  };
};

const generateJson = async (prompt, fallback) => {
  if (!gemini) {
    return fallback();
  }

  const response = await gemini.models.generateContent({
    model: 'gemini-1.5-flash',
    contents: prompt,
    config: {
      temperature: 0.2,
      responseMimeType: 'application/json'
    }
  });

  return safeJsonParse(response.text ?? '{}', fallback());
};

export const analyzeCvText = async (cvText) => {
  const cacheKey = `cv-analysis:${cvText.slice(0, 120)}`;
  const cached = cvAnalysisCache.get(cacheKey);
  if (cached) {
    return cached;
  }

  const result = await generateJson(
    [
      'You are an expert ATS analyst and career coach.',
      'Analyze the following CV text and return ONLY a valid JSON object with no extra text.',
      'The JSON must have keys: completeness_score, ats_score, alignment_score, health_label, suggested_keywords, suggestions.',
      "health_label must be one of 'Good', 'Fair', 'Poor'.",
      "Each suggestion must include type, suggestion, and priority fields.",
      `CV text:\n${cvText}`
    ].join('\n\n'),
    () => heuristicCvAnalysis(cvText)
  );

  cvAnalysisCache.set(cacheKey, result);
  return result;
};

export const scoreJobMatch = async ({ profile, job, weights = {} }) => {
  const cacheKey = `match:${profile.id}:${job.id}:${profile.cv_last_analyzed_at ?? 'na'}`;
  const cached = matchScoreCache.get(cacheKey);
  if (cached) {
    return cached;
  }

  const result = await generateJson(
    [
      'You are a job matching AI.',
      'Return ONLY valid JSON with: match_score, match_label, reason.',
      "match_label must be one of 'Excellent match', 'Strong match', 'Good match', 'Low match'.",
      `Candidate: title=${profile.title ?? ''}, skills=${JSON.stringify(profile.skills ?? [])}, desired_roles=${JSON.stringify(profile.desired_roles ?? [])}, experience summary=${(profile.cv_text ?? '').slice(0, 300)}`,
      `Feed tuning weights=${JSON.stringify(weights)}`,
      `Job: title=${job.title}, company=${job.company}, required_skills=${JSON.stringify(job.required_skills ?? [])}, description=${String(job.description ?? '').slice(0, 400)}`
    ].join('\n\n'),
    () => heuristicMatch({ profile, job })
  );

  matchScoreCache.set(cacheKey, result);
  return result;
};

export const answerCvChat = async ({
  profile,
  message,
  conversationHistory = []
}) => {
  const cacheKey = `chat-history:${profile.id}`;
  const trimmedHistory = [...conversationHistory].slice(-10);

  if (!gemini) {
    const fallbackReply =
      'Focus on stronger impact bullets, clearer skills wording, and tailoring your CV language to the roles you want next.';
    chatHistoryCache.set(cacheKey, [
      ...trimmedHistory,
      { role: 'assistant', content: fallbackReply }
    ]);
    return fallbackReply;
  }

  const prompt = [
    "You are SmartJob's AI career assistant. Be concise, friendly, and specific.",
    `The user's CV summary: ${(profile.cv_text ?? '').slice(0, 500)}`,
    `Target roles: ${JSON.stringify(profile.desired_roles ?? [])}`,
    `Current CV health: ${profile.cv_health ?? 'Unknown'}`,
    `Conversation history: ${JSON.stringify(trimmedHistory)}`,
    `User message: ${message}`
  ].join('\n\n');

  const response = await gemini.models.generateContent({
    model: 'gemini-1.5-flash',
    contents: prompt,
    config: {
      temperature: 0.6
    }
  });

  const reply = (response.text ?? '').trim();
  chatHistoryCache.set(cacheKey, [
    ...trimmedHistory,
    { role: 'user', content: message },
    { role: 'assistant', content: reply }
  ].slice(-10));
  return reply;
};

export const improveCvSection = async ({
  sectionName,
  sectionText,
  targetRole
}) => {
  if (!gemini) {
    return sectionText.trim();
  }

  const response = await gemini.models.generateContent({
    model: 'gemini-1.5-flash',
    contents: [
      `Rewrite the following CV section to be more impactful, ATS-optimized, and tailored for a ${targetRole || 'target'} role.`,
      'Use strong action verbs. Keep it truthful and professional.',
      'Return ONLY the improved text, no commentary, no labels.',
      `Section: ${sectionName}`,
      `Original text: ${sectionText}`
    ].join('\n\n'),
    config: {
      temperature: 0.4
    }
  });

  return (response.text ?? '').trim();
};

export const analyzeKeywordGap = async ({
  candidateSkills,
  jobMarketText
}) => {
  if (!gemini) {
    const normalizedSkills = new Set(
      (candidateSkills ?? []).map((skill) => skill.toLowerCase())
    );
    const presentKeywords = [...normalizedSkills].slice(0, 5);
    const missingKeywords = commonSkillHints
      .filter((skill) => !normalizedSkills.has(skill.toLowerCase()))
      .slice(0, 10);
    return {
      missing_keywords: missingKeywords,
      present_keywords: presentKeywords
    };
  }

  return generateJson(
    [
      'Compare this candidate skills profile with the skills demanded across these job listings.',
      'Return ONLY valid JSON with missing_keywords and present_keywords arrays.',
      `Candidate skills: ${JSON.stringify(candidateSkills ?? [])}`,
      `Job market skills: ${jobMarketText}`
    ].join('\n\n'),
    () => ({ missing_keywords: [], present_keywords: [] })
  );
};

export const extractSkillsFromDescription = async (description) => {
  if (!description) {
    return [];
  }

  if (!gemini) {
    const lower = description.toLowerCase();
    return commonSkillHints
      .filter((skill) => lower.includes(skill.toLowerCase()))
      .slice(0, 6);
  }

  const result = await generateJson(
    [
      'Extract the top 6 required technical skills from this job description as a JSON array of short strings.',
      'Return ONLY the JSON array, nothing else.',
      `Description: ${description.slice(0, 1200)}`
    ].join('\n\n'),
    () => []
  );

  return Array.isArray(result) ? result.slice(0, 6) : [];
};
