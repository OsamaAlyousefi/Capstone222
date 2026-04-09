import axios from 'axios';

import { config } from '../config.js';
import { stripHtml } from '../utils/stripHtml.js';
import { extractSkillsFromDescription } from './gemini.js';

const adzunaClient = axios.create({
  baseURL: 'https://api.adzuna.com/v1/api/jobs',
  timeout: 20000
});

export const isAdzunaConfigured = Boolean(
  config.adzunaAppId && config.adzunaAppKey
);

const inferWorkMode = (description, location) => {
  const haystack = `${description} ${location}`.toLowerCase();
  if (haystack.includes('remote')) {
    return 'Remote';
  }
  if (haystack.includes('hybrid')) {
    return 'Hybrid';
  }
  return 'On-site';
};

const inferEmploymentType = (description) => {
  const lower = description.toLowerCase();
  if (lower.includes('part time')) {
    return 'Part time';
  }
  if (lower.includes('intern')) {
    return 'Internship';
  }
  if (lower.includes('contract')) {
    return 'Contract';
  }
  return 'Full time';
};

export const normalizeAdzunaJob = async (rawJob) => {
  const description = stripHtml(rawJob.description ?? '');

  return {
    external_id: String(rawJob.id),
    source: 'adzuna',
    title: rawJob.title ?? 'Untitled role',
    company: rawJob.company?.display_name ?? 'Unknown company',
    company_logo_url: null,
    location: rawJob.location?.display_name ?? 'Unknown location',
    work_mode: inferWorkMode(description, rawJob.location?.display_name ?? ''),
    employment_type: inferEmploymentType(description),
    salary_min: rawJob.salary_min ? Math.round(rawJob.salary_min) : null,
    salary_max: rawJob.salary_max ? Math.round(rawJob.salary_max) : null,
    salary_currency: 'AED',
    description,
    required_skills: await extractSkillsFromDescription(description),
    apply_url: rawJob.redirect_url ?? rawJob.redirectUrl ?? '',
    redirect_url: rawJob.redirect_url ?? rawJob.redirectUrl ?? '',
    posted_at: rawJob.created ?? new Date().toISOString(),
    fetched_at: new Date().toISOString(),
    is_easy_apply: false,
    is_active: true
  };
};

export const fetchAdzunaJobs = async ({
  role,
  location,
  page = 1,
  resultsPerPage = 20
}) => {
  if (!isAdzunaConfigured) {
    return [];
  }

  const response = await adzunaClient.get(
    `/${config.adzunaCountry}/search/${page}`,
    {
      params: {
        app_id: config.adzunaAppId,
        app_key: config.adzunaAppKey,
        results_per_page: resultsPerPage,
        what: role,
        where: location,
        'content-type': 'application/json'
      }
    }
  );

  const results = response.data?.results ?? [];
  return Promise.all(results.map((job) => normalizeAdzunaJob(job)));
};
