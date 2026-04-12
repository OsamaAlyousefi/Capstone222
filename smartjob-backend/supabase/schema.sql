create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text default '',
  title text default '',
  phone text,
  location text,
  linkedin_url text,
  github_url text,
  website_url text,
  avatar_url text,
  desired_roles text[] not null default '{}',
  employment_types text[] not null default '{}',
  work_modes text[] not null default '{}',
  preferred_locations text[] not null default '{}',
  skills text[] not null default '{}',
  alert_frequency text not null default 'Daily',
  push_alerts_enabled boolean not null default true,
  email_alerts_enabled boolean not null default true,
  cv_url text,
  cv_text text,
  cv_score integer,
  cv_health text,
  cv_completeness integer,
  cv_ats_score integer,
  cv_alignment_score integer,
  cv_last_analyzed_at timestamptz,
  smartjob_inbox_email text,
  fcm_token text,
  user_feed_weights jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, smartjob_inbox_email, created_at, updated_at)
  values (
    new.id,
    coalesce(new.email, ''),
    left(replace(new.id::text, '-', ''), 12) || '@smartjob.app',
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  external_id text not null unique,
  source text not null default 'adzuna',
  title text not null,
  company text not null,
  company_logo_url text,
  location text,
  work_mode text,
  employment_type text,
  salary_min integer,
  salary_max integer,
  salary_currency text not null default 'AED',
  description text,
  required_skills text[] not null default '{}',
  apply_url text,
  redirect_url text,
  posted_at timestamptz,
  fetched_at timestamptz not null default timezone('utc', now()),
  is_easy_apply boolean not null default false,
  is_active boolean not null default true
);

create table if not exists public.user_job_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  action text,
  match_score integer,
  match_label text,
  match_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, job_id)
);

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  status text not null default 'pending',
  applied_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  notes text,
  source text not null default 'easy_apply'
);

create table if not exists public.inbox_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  application_id uuid references public.applications(id) on delete set null,
  sender_name text,
  sender_email text,
  subject text,
  body text,
  received_at timestamptz not null default timezone('utc', now()),
  is_read boolean not null default false,
  category text not null default 'update'
);

create table if not exists public.cv_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  suggestion text not null,
  priority text not null,
  resolved boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, token)
);

create table if not exists public.cv_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  cv_url text not null,
  cv_score integer,
  uploaded_at timestamptz not null default timezone('utc', now())
);

create trigger set_profiles_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

create trigger set_applications_updated_at
before update on public.applications
for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.jobs enable row level security;
alter table public.user_job_interactions enable row level security;
alter table public.applications enable row level security;
alter table public.inbox_messages enable row level security;
alter table public.cv_suggestions enable row level security;
alter table public.device_tokens enable row level security;
alter table public.cv_history enable row level security;

create policy "profiles_select_own"
on public.profiles for select
using (auth.uid() = id);

create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = id);

create policy "profiles_insert_own"
on public.profiles for insert
with check (auth.uid() = id);

create policy "jobs_public_read"
on public.jobs for select
using (true);

create policy "interactions_select_own"
on public.user_job_interactions for select
using (auth.uid() = user_id);

create policy "interactions_insert_own"
on public.user_job_interactions for insert
with check (auth.uid() = user_id);

create policy "interactions_update_own"
on public.user_job_interactions for update
using (auth.uid() = user_id);

create policy "applications_select_own"
on public.applications for select
using (auth.uid() = user_id);

create policy "applications_insert_own"
on public.applications for insert
with check (auth.uid() = user_id);

create policy "applications_update_own"
on public.applications for update
using (auth.uid() = user_id);

create policy "applications_delete_own"
on public.applications for delete
using (auth.uid() = user_id);

create policy "inbox_select_own"
on public.inbox_messages for select
using (auth.uid() = user_id);

create policy "inbox_insert_own"
on public.inbox_messages for insert
with check (auth.uid() = user_id);

create policy "inbox_update_own"
on public.inbox_messages for update
using (auth.uid() = user_id);

create policy "inbox_delete_own"
on public.inbox_messages for delete
using (auth.uid() = user_id);

create policy "suggestions_select_own"
on public.cv_suggestions for select
using (auth.uid() = user_id);

create policy "suggestions_insert_own"
on public.cv_suggestions for insert
with check (auth.uid() = user_id);

create policy "suggestions_update_own"
on public.cv_suggestions for update
using (auth.uid() = user_id);

create policy "device_tokens_select_own"
on public.device_tokens for select
using (auth.uid() = user_id);

create policy "device_tokens_insert_own"
on public.device_tokens for insert
with check (auth.uid() = user_id);

create policy "device_tokens_delete_own"
on public.device_tokens for delete
using (auth.uid() = user_id);

create policy "cv_history_select_own"
on public.cv_history for select
using (auth.uid() = user_id);

create policy "cv_history_insert_own"
on public.cv_history for insert
with check (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('cvs', 'cvs', true)
on conflict (id) do nothing;


create policy "cv_storage_public_read"
on storage.objects for select
using (bucket_id = 'cvs');

create policy "cv_storage_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'cvs'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "cv_storage_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'cvs'
  and auth.uid()::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'cvs'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "cv_storage_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'cvs'
  and auth.uid()::text = (storage.foldername(name))[1]
);
