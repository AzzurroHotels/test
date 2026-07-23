-- Azzurro Operations Workspace
-- Fresh setup for Supabase SQL Editor.
-- This script contains only the current login, project dashboard, and maintenance tracker schema.

begin;

create extension if not exists pgcrypto;

create table if not exists public.maintenance_task_types (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (length(btrim(name)) between 1 and 120),
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.maintenance_records (
  id uuid primary key default gen_random_uuid(),
  task_type_id uuid not null references public.maintenance_task_types(id) on delete restrict,
  property text not null check (length(btrim(property)) between 1 and 200),
  area text,
  assigned_to text,
  scheduled_date date not null,
  scheduled_time time,
  frequency text not null default 'One-time' check (frequency in ('One-time', 'Daily', 'Weekly', 'Fortnightly', 'Monthly', 'Quarterly')),
  status text not null default 'Scheduled' check (status in ('Scheduled', 'In Progress', 'Completed')),
  completed_date date,
  notes text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint maintenance_completed_date_check check (status <> 'Completed' or completed_date is not null)
);

create table if not exists public.project_tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) between 1 and 200),
  description text,
  project_name text,
  sprint_name text,
  status text not null default 'Backlog' check (status in ('Backlog', 'To Do', 'In Progress', 'Done')),
  priority text not null default 'Medium' check (priority in ('Critical', 'High', 'Medium', 'Low')),
  assignee text,
  due_date date,
  labels text,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.receptionists (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(btrim(full_name)) between 1 and 160),
  email text,
  phone text,
  primary_property text,
  employment_type text not null default 'Full-time' check (employment_type in ('Full-time', 'Part-time', 'Casual', 'Contractor', 'Other')),
  start_date date not null,
  contract_termination_date date,
  notes text,
  is_archived boolean not null default false,
  archived_at timestamptz,
  archived_by uuid references auth.users(id) on delete set null,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint receptionist_contract_date_check check (contract_termination_date is null or contract_termination_date >= start_date),
  constraint receptionist_archive_check check (
    (is_archived = false and archived_at is null) or
    (is_archived = true and archived_at is not null)
  )
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists maintenance_task_types_set_updated_at on public.maintenance_task_types;
create trigger maintenance_task_types_set_updated_at
before update on public.maintenance_task_types
for each row execute function public.set_updated_at();

drop trigger if exists maintenance_records_set_updated_at on public.maintenance_records;
create trigger maintenance_records_set_updated_at
before update on public.maintenance_records
for each row execute function public.set_updated_at();

drop trigger if exists project_tasks_set_updated_at on public.project_tasks;
create trigger project_tasks_set_updated_at
before update on public.project_tasks
for each row execute function public.set_updated_at();

drop trigger if exists receptionists_set_updated_at on public.receptionists;
create trigger receptionists_set_updated_at
before update on public.receptionists
for each row execute function public.set_updated_at();

create index if not exists project_tasks_status_idx on public.project_tasks(status);
create index if not exists project_tasks_sprint_idx on public.project_tasks(sprint_name);
create index if not exists project_tasks_project_idx on public.project_tasks(project_name);
create index if not exists project_tasks_due_date_idx on public.project_tasks(due_date);
create index if not exists maintenance_records_date_idx on public.maintenance_records(scheduled_date);
create index if not exists maintenance_records_task_type_idx on public.maintenance_records(task_type_id);
create index if not exists maintenance_records_status_idx on public.maintenance_records(status);
create index if not exists receptionists_archive_idx on public.receptionists(is_archived);
create index if not exists receptionists_name_idx on public.receptionists(full_name);
create index if not exists receptionists_contract_end_idx on public.receptionists(contract_termination_date);

alter table public.maintenance_task_types enable row level security;
alter table public.maintenance_records enable row level security;
alter table public.project_tasks enable row level security;
alter table public.receptionists enable row level security;

-- Remove policies from previous drafts, if any.
drop policy if exists "anon task types" on public.maintenance_task_types;
drop policy if exists "anon maintenance records" on public.maintenance_records;
drop policy if exists "anon project tasks" on public.project_tasks;
drop policy if exists "authenticated task types" on public.maintenance_task_types;
drop policy if exists "authenticated maintenance records" on public.maintenance_records;
drop policy if exists "authenticated project tasks" on public.project_tasks;
drop policy if exists "authenticated receptionists" on public.receptionists;

-- Shared internal workspace: every authenticated user can access the same data.
create policy "authenticated task types"
on public.maintenance_task_types
for all
to authenticated
using (true)
with check (true);

create policy "authenticated maintenance records"
on public.maintenance_records
for all
to authenticated
using (true)
with check (true);

create policy "authenticated project tasks"
on public.project_tasks
for all
to authenticated
using (true)
with check (true);

create policy "authenticated receptionists"
on public.receptionists
for all
to authenticated
using (true)
with check (true);

-- Explicit API privileges. Anonymous visitors get no table access.
revoke all on table public.maintenance_task_types from anon;
revoke all on table public.maintenance_records from anon;
revoke all on table public.project_tasks from anon;
revoke all on table public.receptionists from anon;

grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.maintenance_task_types to authenticated;
grant select, insert, update, delete on table public.maintenance_records to authenticated;
grant select, insert, update, delete on table public.project_tasks to authenticated;
grant select, insert, update, delete on table public.receptionists to authenticated;

insert into public.maintenance_task_types (name, sort_order)
values
  ('Bathroom Deep Cleaning', 1),
  ('Laundry Tub Hygiene Cleaning', 2),
  ('Returning Mail to Post Office', 3),
  ('Room Pest Spray', 4)
on conflict (name) do update
set sort_order = excluded.sort_order;

commit;
