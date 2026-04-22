-- V1 · compliance_request_status enum completion · shipped missing 'cancelled' value
-- Why standalone:
--   · V6 account_deletion_cancel_own policy uses status in ('pending', 'cancelled')
--   · V1 enum definition forgot 'cancelled' (drift vs Android ComplianceRequestStatus enum
--     which correctly ships all 6 values · see AccountDeletionRequestEntity.kt · DataExportRequestEntity.kt)
--   · Postgres allows ALTER TYPE ADD VALUE inside a transaction but the new value cannot
--     be used in the same transaction it was added · so this must run as its own migration
--     before V6's policy references 'cancelled'
-- Cross-platform · no Kotlin/Swift change required now:
--   · Android entity already defines CANCELLED("cancelled") · parity restored once this applies
--   · iOS entities (Phase 1 R2 · not yet built) must include all 6 values when drafted
-- Renumbering note (R21):
--   · Previous V5 (compliance) renamed to V6
--   · Previous V6 (night_log) renamed to V7
--   · Previous V7 (feature_flags) renamed to V8
--   · Android entity comments (V5/V6/V7 tags in doc strings) to be updated post-push · see R21 doc
-- Paper trail · Round 21 · V3/V4 ordering + V1 enum completion + V5-V7 renumber

alter type public.compliance_request_status add value if not exists 'cancelled';

comment on type public.compliance_request_status is
  'Lifecycle of compliance requests (data_export · account_deletion) · 6 values · terminal states = delivered / failed / cancelled · R21 ensured cancelled landed after V1 shipped incomplete';
