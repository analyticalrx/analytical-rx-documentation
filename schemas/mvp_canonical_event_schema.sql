-- AnalyticalRx MVP canonical event schema draft.
-- Target database: PostgreSQL-compatible engine such as AWS RDS PostgreSQL or Aurora PostgreSQL.
-- Purpose: store PrimeRx webhook/API events safely while separating restricted source identifiers from analytics-facing canonical records.

create extension if not exists pgcrypto;

create schema if not exists core;
create schema if not exists ops;
create schema if not exists analytics;

create table if not exists core.tenant (
  id uuid primary key default gen_random_uuid(),
  tenant_key text not null unique,
  display_name text not null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists core.pharmacy (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references core.tenant(id),
  pharmacy_key text not null,
  source_system text not null,
  source_pharmacy_id text,
  display_name text not null,
  npi text,
  ncpdp text,
  state_code text,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, pharmacy_key)
);

create table if not exists ops.raw_payload_archive (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references core.tenant(id),
  pharmacy_id uuid references core.pharmacy(id),
  source_system text not null,
  source_event_type text,
  raw_payload_reference text not null,
  raw_payload_sha256 text not null,
  payload_size_bytes integer,
  received_at timestamptz not null default now(),
  retention_until date,
  created_at timestamptz not null default now(),
  unique (tenant_id, source_system, raw_payload_sha256)
);

create table if not exists ops.source_prescription_reference_restricted (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references core.tenant(id),
  pharmacy_id uuid not null references core.pharmacy(id),
  source_system text not null,
  source_pharmacy_id text,
  rx_no text not null,
  refill_no text,
  prescription_reference_token text not null,
  fill_reference_token text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, fill_reference_token)
);

create table if not exists ops.webhook_event_audit (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references core.tenant(id),
  pharmacy_id uuid references core.pharmacy(id),
  source_system text not null,
  source_event_id text,
  source_event_type text not null,
  receiver_request_id text,
  idempotency_key text not null,
  source_reference_id uuid references ops.source_prescription_reference_restricted(id),
  raw_payload_archive_id uuid references ops.raw_payload_archive(id),
  received_at timestamptz not null default now(),
  queued_at timestamptz,
  processing_started_at timestamptz,
  processed_at timestamptz,
  status text not null check (
    status in (
      'received',
      'queued',
      'processing',
      'processed',
      'failed',
      'duplicate',
      'unsupported_event_type',
      'needs_enrichment'
    )
  ),
  phi_suppression_status text not null default 'not_started' check (
    phi_suppression_status in ('not_started', 'suppressed', 'not_required', 'failed')
  ),
  duplicate_of uuid references ops.webhook_event_audit(id),
  failure_code text,
  failure_reason text,
  schema_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, source_system, idempotency_key)
);

create table if not exists analytics.canonical_pharmacy_event (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references core.tenant(id),
  pharmacy_id uuid not null references core.pharmacy(id),
  audit_event_id uuid not null unique references ops.webhook_event_audit(id),
  source_system text not null,
  source_event_type text not null,
  canonical_event_type text not null check (
    canonical_event_type in (
      'prescription_saved',
      'prescription_filed',
      'claim_billed',
      'claim_reversed',
      'claim_rejected',
      'fulfillment_delivery',
      'fulfillment_shipped',
      'label_printed',
      'workflow_transition',
      'prescription_deleted',
      'patient_updated',
      'unknown'
    )
  ),
  event_timestamp timestamptz,
  business_date date,
  prescription_reference_token text,
  fill_reference_token text,
  rx_status text,
  claim_status text,
  fulfillment_status text,
  queue_status text,
  drug_ndc text,
  drug_name text,
  drug_generic_name text,
  payer_name text,
  payer_bin text,
  payer_pcn text,
  prescriber_npi text,
  total_amount numeric(12,2),
  insurance_paid_amount numeric(12,2),
  patient_pay_amount numeric(12,2),
  copay_paid_amount numeric(12,2),
  reversal_flag boolean not null default false,
  rejection_code text,
  rejection_reason_category text,
  enrichment_status text not null default 'pending' check (
    enrichment_status in ('not_required', 'pending', 'complete', 'failed')
  ),
  data_quality_status text not null default 'partial' check (
    data_quality_status in ('valid', 'partial', 'invalid', 'needs_review')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_pharmacy_tenant on core.pharmacy (tenant_id);
create unique index if not exists uq_pharmacy_source_id
  on core.pharmacy (tenant_id, source_system, (coalesce(source_pharmacy_id, '')));
create index if not exists idx_raw_payload_tenant_received on ops.raw_payload_archive (tenant_id, received_at);
create index if not exists idx_source_ref_prescription_token on ops.source_prescription_reference_restricted (tenant_id, prescription_reference_token);
create index if not exists idx_source_ref_fill_token on ops.source_prescription_reference_restricted (tenant_id, fill_reference_token);
create unique index if not exists uq_source_ref_rx_fill
  on ops.source_prescription_reference_restricted (tenant_id, pharmacy_id, source_system, rx_no, (coalesce(refill_no, '')));
create index if not exists idx_source_ref_rx on ops.source_prescription_reference_restricted (tenant_id, pharmacy_id, source_system, rx_no, refill_no);
create index if not exists idx_audit_status_received on ops.webhook_event_audit (tenant_id, status, received_at);
create index if not exists idx_audit_source_type on ops.webhook_event_audit (tenant_id, source_system, source_event_type, received_at);
create index if not exists idx_canonical_business_date on analytics.canonical_pharmacy_event (tenant_id, pharmacy_id, business_date);
create index if not exists idx_canonical_event_type on analytics.canonical_pharmacy_event (tenant_id, canonical_event_type, business_date);
create index if not exists idx_canonical_fill_token on analytics.canonical_pharmacy_event (tenant_id, fill_reference_token);

-- Recommended access model:
-- 1. Ingestion/processor service role can write ops.* and analytics.canonical_pharmacy_event.
-- 2. API enrichment service role can read ops.source_prescription_reference_restricted.
-- 3. Dashboard/analytics role should read analytics.* only.
-- 4. Raw payload archive references point to restricted encrypted object storage; raw JSON should not be copied into analytics tables.
