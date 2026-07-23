-- Reception Management tab migration
-- Run this once in the Supabase SQL Editor for the existing workspace.

begin;

create extension if not exists pgcrypto;

create table if not exists public.receptionists (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(btrim(full_name)) between 1 and 160),
  email text,
  phone text,
  primary_property text,
  employment_type text not null default 'Full-time'
    check (employment_type in ('Full-time', 'Part-time', 'Casual', 'Contractor', 'Other')),
  start_date date not null,
  contract_termination_date date,
  notes text,
  is_archived boolean not null default false,
  archived_at timestamptz,
  archived_by uuid references auth.users(id) on delete set null,
  created_by uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint receptionist_contract_date_check
    check (contract_termination_date is null or contract_termination_date >= start_date),
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

drop trigger if exists receptionists_set_updated_at on public.receptionists;
create trigger receptionists_set_updated_at
before update on public.receptionists
for each row execute function public.set_updated_at();

create index if not exists receptionists_archive_idx on public.receptionists(is_archived);
create index if not exists receptionists_name_idx on public.receptionists(full_name);
create index if not exists receptionists_contract_end_idx on public.receptionists(contract_termination_date);

alter table public.receptionists enable row level security;

drop policy if exists "authenticated receptionists" on public.receptionists;
create policy "authenticated receptionists"
on public.receptionists
for all
to authenticated
using (true)
with check (true);

revoke all on table public.receptionists from anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.receptionists to authenticated;

commit;
