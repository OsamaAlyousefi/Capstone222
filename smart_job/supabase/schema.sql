create table if not exists public.smart_job_accounts (
  email text primary key,
  full_name text not null default '',
  account_data jsonb not null,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.smart_job_accounts enable row level security;

create policy "smart_job_accounts_dev_access"
on public.smart_job_accounts
for all
using (true)
with check (true);

insert into storage.buckets (id, name, public)
values ('smart-job-cvs', 'smart-job-cvs', false)
on conflict (id) do nothing;

create policy "smart_job_cvs_dev_access"
on storage.objects
for all
using (bucket_id = 'smart-job-cvs')
with check (bucket_id = 'smart-job-cvs');
