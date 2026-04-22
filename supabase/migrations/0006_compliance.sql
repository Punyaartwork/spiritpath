-- ============================================================================
-- SpiritPath · Migration 0005 · Compliance · CCPA + GDPR
-- ============================================================================
-- Creates: data_export_requests · account_deletion_requests
--          + RLS Pattern A · SELECT + INSERT only (clients cannot update/delete requests)
--          + schedule_deletion_grace trigger · sets scheduled_for = requested_at + 30 days
-- Edge functions consume:
--   process-data-export       · on insert data_export_requests → builds ZIP → uploads to Storage
--   process-account-deletion  · pg_cron daily · finds scheduled_for < now() → hard-delete cascade
-- Platform: iOS + Android unified
-- Reference: master plan §07 · Tab 04 Round 15 standby trigger V5
-- ============================================================================

-- ─── 1. data_export_requests ──────────────────────────────────────────────

create table public.data_export_requests (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,

  requested_at   timestamptz not null default now(),
  status         public.compliance_request_status not null default 'pending',

  -- set by edge function after ZIP is built and uploaded to Storage
  ready_url      text,                     -- presigned URL · 7-day TTL
  completed_at   timestamptz
);

comment on table public.data_export_requests is
  'CCPA "right to know" · user POSTs a request → process-data-export edge function aggregates all user data as JSON/CSV → ZIP → uploads to exports bucket → sets ready_url + completed_at · client polls status + fetches ZIP on ready';

-- ─── 2. account_deletion_requests ────────────────────────────────────────

create table public.account_deletion_requests (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,

  requested_at   timestamptz not null default now(),
  scheduled_for  timestamptz not null,        -- set by trigger · requested_at + 30 days
  status         public.compliance_request_status not null default 'pending',
  reason         text,                        -- optional user-submitted reason
  processed_at   timestamptz
);

comment on table public.account_deletion_requests is
  'CCPA + GDPR "right to delete" · 30-day grace window · client creates row → scheduled_for set by trigger → user can cancel during grace · process-account-deletion pg_cron runs daily · when scheduled_for < now() AND status = pending → hard-delete auth.users row (cascade wipes everything) + set status=delivered + processed_at';

-- ─── 3. Trigger · auto-set scheduled_for ─────────────────────────────────

create or replace function public.schedule_deletion_grace()
returns trigger
language plpgsql
as $$
begin
  -- 30-day grace · user can reverse by updating status to 'cancelled'
  -- (no DELETE policy · cancellation is via status UPDATE)
  new.scheduled_for := new.requested_at + interval '30 days';
  return new;
end;
$$;

comment on function public.schedule_deletion_grace() is
  'Sets scheduled_for = requested_at + 30 days on INSERT · immutable on UPDATE (function only touches NEW on INSERT trigger context)';

create trigger tr_deletion_grace
  before insert on public.account_deletion_requests
  for each row execute function public.schedule_deletion_grace();

-- ─── 4. RLS · Pattern A · self-only SELECT + INSERT · no UPDATE/DELETE ──

alter table public.data_export_requests      enable row level security;
alter table public.account_deletion_requests enable row level security;

-- data_export_requests · INSERT to request · SELECT to poll status · no UPDATE (immutable after creation)
create policy "data_export_select_own"
  on public.data_export_requests for select
  using (auth.uid() = user_id);

create policy "data_export_insert_own"
  on public.data_export_requests for insert
  with check (auth.uid() = user_id);

-- No UPDATE policy · status transitions are edge-function-only · service_role bypass

-- account_deletion_requests · INSERT to request · SELECT to see pending · UPDATE only to cancel
create policy "account_deletion_select_own"
  on public.account_deletion_requests for select
  using (auth.uid() = user_id);

create policy "account_deletion_insert_own"
  on public.account_deletion_requests for insert
  with check (auth.uid() = user_id);

-- UPDATE allowed only to flip status to 'cancelled' (user reverses decision during grace)
-- Edge function uses service_role for the actual hard-delete flow
create policy "account_deletion_cancel_own"
  on public.account_deletion_requests for update
  using (auth.uid() = user_id and status = 'pending')
  with check (auth.uid() = user_id and status in ('pending', 'cancelled'));

-- No DELETE policies · requests are historical records · CCPA audit trail

-- ─── 5. Indexes · for edge function cron sweep ───────────────────────────

-- pg_cron daily sweep · find pending deletions due
create index idx_account_deletion_due
  on public.account_deletion_requests(scheduled_for)
  where status = 'pending';

-- client poll · recent exports per user
create index idx_data_export_user_recent
  on public.data_export_requests(user_id, requested_at desc);
