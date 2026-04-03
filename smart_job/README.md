# smart_job

SmartJob is a Flutter job-search app with a local Hive database, optional Supabase account sync, and real CV file upload support.

## Backend setup

SmartJob runs in local-only mode by default. To enable the remote backend, create the table and storage bucket in Supabase with [supabase/schema.sql](supabase/schema.sql), then launch the app with Dart defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=your-project-url \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## What syncs

- account profile data
- saved jobs and recruiter feedback
- applications and inbox messages
- onboarding progress and CV insights
- uploaded CV files to the `smart-job-cvs` storage bucket

If the Supabase keys are missing or the backend is unavailable, SmartJob falls back to the local Hive database so the app still works offline.
