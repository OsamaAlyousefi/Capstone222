import { v4 as uuidv4 } from 'uuid';

import { supabaseAdmin } from '../services/supabase.js';

const mockJobs = [
  ['Flutter Developer', 'Dubai', 'Remote'],
  ['Senior Flutter Engineer', 'Abu Dhabi', 'Hybrid'],
  ['Mobile App Developer', 'Sharjah', 'On-site'],
  ['Product Designer', 'Dubai', 'Hybrid'],
  ['UX Designer', 'Remote', 'Remote'],
  ['UI/UX Designer', 'Dubai', 'On-site'],
  ['Product Manager', 'Abu Dhabi', 'Hybrid'],
  ['QA Engineer', 'Dubai', 'On-site'],
  ['Frontend Developer', 'Remote', 'Remote'],
  ['React Native Developer', 'Dubai', 'Hybrid'],
  ['Junior Flutter Developer', 'Ajman', 'On-site'],
  ['Design Systems Designer', 'Remote', 'Remote'],
  ['Mobile Product Designer', 'Dubai', 'Hybrid'],
  ['Full Stack Developer', 'Abu Dhabi', 'Hybrid'],
  ['Software Engineer', 'Dubai', 'On-site'],
  ['Customer Experience Designer', 'Remote', 'Remote'],
  ['UX Researcher', 'Dubai', 'Hybrid'],
  ['Interaction Designer', 'Sharjah', 'On-site'],
  ['Growth Product Designer', 'Remote', 'Remote'],
  ['Technical Product Manager', 'Dubai', 'Hybrid'],
  ['API Integration Engineer', 'Abu Dhabi', 'On-site'],
  ['Mobile QA Analyst', 'Dubai', 'Hybrid'],
  ['Visual Designer', 'Remote', 'Remote'],
  ['Product Analyst', 'Dubai', 'On-site'],
  ['Junior UX Designer', 'Abu Dhabi', 'Hybrid']
].map(([title, location, workMode], index) => ({
  id: uuidv4(),
  external_id: `mock-${index + 1}`,
  source: 'seed',
  title,
  company: [
    'Northstar Labs',
    'Signal Hire',
    'Palm Orbit',
    'Desert Pixel',
    'Blue Dune Tech'
  ][index % 5],
  company_logo_url: null,
  location,
  work_mode: workMode,
  employment_type: index % 6 === 0 ? 'Part time' : 'Full time',
  salary_min: 6000 + index * 500,
  salary_max: 10000 + index * 700,
  salary_currency: 'AED',
  description:
    `${title} role focused on product quality, collaboration, and modern digital experiences. ` +
    'Looking for candidates with Flutter, design thinking, communication, and delivery skills.',
  required_skills: ['Flutter', 'Communication', 'REST APIs', 'Agile', 'Figma'].slice(
    0,
    3 + (index % 3)
  ),
  apply_url: 'https://example.com/apply',
  redirect_url: 'https://example.com/apply',
  posted_at: new Date(Date.now() - index * 8 * 60 * 60 * 1000).toISOString(),
  fetched_at: new Date().toISOString(),
  is_easy_apply: index % 4 === 0,
  is_active: true
}));

const seed = async () => {
  const { error } = await supabaseAdmin
    .from('jobs')
    .upsert(mockJobs, { onConflict: 'external_id' });

  if (error) {
    console.error('Failed to seed jobs:', error);
    process.exitCode = 1;
    return;
  }

  console.log(`Seeded ${mockJobs.length} jobs.`);
};

seed();
