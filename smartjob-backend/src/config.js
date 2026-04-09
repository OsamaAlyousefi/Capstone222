import dotenv from 'dotenv';

dotenv.config();

const parseJson = (value, fallback) => {
  if (!value) {
    return fallback;
  }

  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
};

export const config = {
  port: Number.parseInt(process.env.PORT ?? '3000', 10),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  clientOrigin: process.env.CLIENT_ORIGIN ?? '*',
  supabaseUrl: process.env.SUPABASE_URL ?? '',
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? '',
  supabaseAnonKey: process.env.SUPABASE_ANON_KEY ?? '',
  geminiApiKey: process.env.GEMINI_API_KEY ?? '',
  adzunaAppId: process.env.ADZUNA_APP_ID ?? '',
  adzunaAppKey: process.env.ADZUNA_APP_KEY ?? '',
  adzunaCountry: process.env.ADZUNA_COUNTRY ?? 'ae',
  fcmServiceAccount: parseJson(process.env.FCM_SERVICE_ACCOUNT_JSON, null),
  isProduction: (process.env.NODE_ENV ?? 'development') === 'production'
};

export const requireConfig = (...keys) => {
  const missing = keys.filter((key) => !config[key]);
  if (missing.length > 0) {
    throw new Error(`Missing required config keys: ${missing.join(', ')}`);
  }
};
