# SmartJob Backend

Free-tier backend for SmartJob using:

- Express.js
- Supabase Postgres/Auth/Storage
- Gemini API for CV and job intelligence
- Adzuna Jobs API
- Firebase Cloud Messaging

## Why `@google/genai` instead of `@google/generative-ai`

Google's current official Gemini docs recommend the newer `@google/genai` JavaScript SDK. This backend uses that supported SDK while still following your Gemini free-tier architecture and `gemini-1.5-flash` model choice.

## Quick start

1. Copy `.env.example` to `.env`
2. Fill in the Supabase, Gemini, Adzuna, and Firebase values
3. Run the SQL in [supabase/schema.sql](./supabase/schema.sql)
4. Install packages: `npm install`
5. Start the API: `npm run dev`

## Scripts

- `npm run dev` starts the API with file watching
- `npm run start` starts the API normally
- `npm run seed` inserts 25 realistic mock jobs
- `npm run check` runs a Node syntax check

## API base

- Base URL: `/api/v1`
- Health check: `GET /health`
- All `/api/v1/*` routes require `Authorization: Bearer {supabase_jwt}`

## Notes

- CV uploads are stored in the public Supabase storage bucket `cvs`
- AI-heavy endpoints fall back to deterministic heuristics when Gemini is not configured
- Adzuna sync gracefully skips when credentials are missing
- Daily and weekly digests are started from `src/server.js` through `node-cron`
