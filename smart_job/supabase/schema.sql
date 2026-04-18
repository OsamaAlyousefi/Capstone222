-- ============================================================
-- SmartJob – Full Supabase Schema
-- Run the entire file in the Supabase SQL Editor (one shot).
-- Safe to re-run: uses IF NOT EXISTS / ON CONFLICT guards.
-- ============================================================

-- ─── Profiles ────────────────────────────────────────────────
create table if not exists public.profiles (
  id                    uuid        primary key references auth.users(id) on delete cascade,
  email                 text        not null default '',
  full_name             text        not null default '',
  phone                 text        not null default '',
  location              text        not null default '',
  title                 text        not null default '',
  skills                text[]      not null default '{}',
  linkedin_url          text        not null default '',
  github_url            text        not null default '',
  website_url           text        not null default '',
  smartjob_inbox_email  text        not null default '',
  desired_roles         text[]      not null default '{}',
  preferred_locations   text[]      not null default '{}',
  employment_types      text[]      not null default '{}',
  work_modes            text[]      not null default '{}',
  push_alerts_enabled   boolean     not null default true,
  email_alerts_enabled  boolean     not null default true,
  alert_frequency       text        not null default 'daily',
  cv_url                text        not null default '',
  cv_completeness       integer     not null default 0,
  cv_ats_score          integer     not null default 0,
  cv_alignment_score    integer     not null default 0,
  is_public             boolean     not null default false,
  hide_contact_info     boolean     not null default false,
  privacy_mode          boolean     not null default false,
  updated_at            timestamptz not null default timezone('utc', now())
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_own_access" on public.profiles;
create policy "profiles_own_access"
  on public.profiles for all
  to authenticated
  using  (auth.uid() = id)
  with check (auth.uid() = id);

-- Auto-create a profile row whenever a new user signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Safe column additions for existing deployments
alter table public.profiles add column if not exists is_public boolean not null default false;
alter table public.profiles add column if not exists hide_contact_info boolean not null default false;
alter table public.profiles add column if not exists privacy_mode boolean not null default false;

-- ─── Jobs ─────────────────────────────────────────────────────
create table if not exists public.jobs (
  id               uuid        primary key default gen_random_uuid(),
  title            text        not null default '',
  company          text        not null default '',
  location         text        not null default '',
  source           text        not null default 'SmartJob',
  description      text        not null default '',
  required_skills  text[]      not null default '{}',
  work_mode        text        not null default 'remote',
  employment_type  text        not null default 'full_time',
  salary_currency  text        not null default 'AED',
  salary_min       numeric,
  salary_max       numeric,
  is_active        boolean     not null default true,
  is_easy_apply    boolean     not null default true,
  posted_at        timestamptz not null default timezone('utc', now()),
  fetched_at       timestamptz not null default timezone('utc', now())
);

alter table public.jobs enable row level security;

drop policy if exists "jobs_public_read" on public.jobs;
create policy "jobs_public_read"
  on public.jobs for select
  using (true);

-- ─── User Job Interactions ────────────────────────────────────
create table if not exists public.user_job_interactions (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references auth.users(id) on delete cascade,
  job_id       uuid        not null references public.jobs(id) on delete cascade,
  action       text        not null default '',
  match_score  integer     not null default 72,
  match_label  text        not null default '',
  match_reason text        not null default '',
  created_at   timestamptz not null default timezone('utc', now()),
  unique (user_id, job_id)
);

alter table public.user_job_interactions enable row level security;

drop policy if exists "interactions_own_access" on public.user_job_interactions;
create policy "interactions_own_access"
  on public.user_job_interactions for all
  to authenticated
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─── Applications ─────────────────────────────────────────────
create table if not exists public.applications (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null references auth.users(id) on delete cascade,
  job_id     uuid        not null references public.jobs(id) on delete cascade,
  status     text        not null default 'pending',
  notes      text        not null default '',
  source     text        not null default 'easy_apply',
  applied_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, job_id)
);

alter table public.applications enable row level security;

drop policy if exists "applications_own_access" on public.applications;
create policy "applications_own_access"
  on public.applications for all
  to authenticated
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─── Inbox Messages ───────────────────────────────────────────
create table if not exists public.inbox_messages (
  id             uuid        primary key default gen_random_uuid(),
  user_id        uuid        not null references auth.users(id) on delete cascade,
  application_id uuid        references public.applications(id) on delete set null,
  sender_name    text        not null default '',
  sender_email   text        not null default '',
  subject        text        not null default '',
  body           text        not null default '',
  category       text        not null default 'update',
  is_read        boolean     not null default false,
  received_at    timestamptz not null default timezone('utc', now())
);

alter table public.inbox_messages enable row level security;

drop policy if exists "inbox_own_access" on public.inbox_messages;
create policy "inbox_own_access"
  on public.inbox_messages for all
  to authenticated
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─── Legacy smart_job_accounts ────────────────────────────────
create table if not exists public.smart_job_accounts (
  email        text        primary key,
  full_name    text        not null default '',
  account_data jsonb       not null,
  updated_at   timestamptz not null default timezone('utc', now())
);

alter table public.smart_job_accounts enable row level security;

drop policy if exists "smart_job_accounts_dev_access" on public.smart_job_accounts;
create policy "smart_job_accounts_dev_access"
  on public.smart_job_accounts for all
  using (true)
  with check (true);

-- ─── Storage bucket: cvs ──────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('cvs', 'cvs', true)
on conflict (id) do nothing;

drop policy if exists "smart_job_cvs_public_read"   on storage.objects;
drop policy if exists "smart_job_cvs_insert_own"    on storage.objects;
drop policy if exists "smart_job_cvs_update_own"    on storage.objects;

create policy "smart_job_cvs_public_read"
  on storage.objects for select
  using (bucket_id = 'cvs');

create policy "smart_job_cvs_insert_own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'cvs'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "smart_job_cvs_update_own"
  on storage.objects for update
  to authenticated
  using  (bucket_id = 'cvs' and auth.uid()::text = (storage.foldername(name))[1])
  with check (bucket_id = 'cvs' and auth.uid()::text = (storage.foldername(name))[1]);
