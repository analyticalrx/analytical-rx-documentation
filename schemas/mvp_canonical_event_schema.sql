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

create table if not exists core.drug (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references core.tenant(id),
  source_system text not null,
  source_drug_id text,
  ndc text,
  drug_name text,
  generic_name text,
  brand_name text,
  is_brand boolean,
  strength text,
  strength_unit text,
  form text,
  manufacturer_name text,
  drug_class text,
  unit_of_measure text,
  quantity_per_pack numeric(12,3),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists core.payer (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references core.tenant(id),
  source_system text not null,
  source_payer_id text,
  payer_type text not null default 'insurance' check (
    payer_type in ('insurance', 'discount_card', 'government', 'other', 'unknown')
  ),
  payer_name text,
  payer_bin text,
  payer_pcn text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
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
  retention_until date not null default (current_date + 30),
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
  drug_id uuid references core.drug(id),
  source_system text not null,
  source_event_type text not null,
  canonical_event_type text not null check (
    canonical_event_type in (
      'patient_created',
      'prescription_saved',
      'prescription_filed',
      'claim_billed',
      'claim_reversed',
      'claim_rejected',
      'fulfillment_picked_up',
      'fulfillment_delivery',
      'fulfillment_shipped',
      'label_printed',
      'drug_pick_verification_done',
      'rph_verification_done',
      'erx_received',
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
  date_ordered timestamptz,
  date_filled timestamptz,
  date_dispensed timestamptz,
  date_picked_up timestamptz,
  picked_up_flag boolean,
  days_supply integer,
  auth_refills integer,
  total_refills integer,
  quantity_ordered numeric(12,3),
  quantity_dispensed numeric(12,3),
  quantity_remaining numeric(12,3),
  rx_status text,
  claim_status text,
  fulfillment_status text,
  queue_status text,
  order_status text,
  refill_queue_status text,
  verification_status text,
  label_printed_flag boolean,
  copay_collected_flag boolean,
  delivery_method text,
  bill_type text,
  rx_origin_code text,
  rx_origin_description text,
  prescriber_npi text,
  total_amount numeric(12,2),
  ingredient_cost_amount numeric(12,2),
  dispensing_fee_amount numeric(12,2),
  other_fee_amount numeric(12,2),
  other_amount numeric(12,2),
  tax_amount numeric(12,2),
  discount_amount numeric(12,2),
  amount_due numeric(12,2),
  reversal_flag boolean not null default false,
  rejection_code text,
  rejection_reason_category text,
  enrichment_status text not null default 'pending' check (
    enrichment_status in ('not_required', 'pending', 'complete', 'failed')
  ),
  data_quality_status text not null default 'partial' check (
    data_quality_status in ('valid', 'partial', 'invalid', 'needs_review')
  ),
  enriched_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists analytics.canonical_event_payer_payment (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references core.tenant(id),
  pharmacy_id uuid not null references core.pharmacy(id),
  canonical_event_id uuid not null references analytics.canonical_pharmacy_event(id) on delete cascade,
  payer_id uuid references core.payer(id),
  payment_type text not null check (
    payment_type in ('insurance', 'cash', 'patient_pay', 'other', 'unknown')
  ),
  payer_sequence text check (
    payer_sequence in ('primary', 'secondary', 'tertiary', 'patient', 'cash', 'other')
  ),
  billed_amount numeric(12,2),
  paid_amount numeric(12,2),
  patient_responsibility_amount numeric(12,2),
  copay_paid_amount numeric(12,2),
  payment_status text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (payment_type <> 'cash' or payer_id is null)
);

create index if not exists idx_pharmacy_tenant on core.pharmacy (tenant_id);
create unique index if not exists uq_pharmacy_source_id
  on core.pharmacy (tenant_id, source_system, (coalesce(source_pharmacy_id, '')));
create index if not exists idx_drug_tenant_name on core.drug (tenant_id, drug_name);
create unique index if not exists uq_drug_source_ndc
  on core.drug (tenant_id, source_system, ndc)
  where ndc is not null;
create unique index if not exists uq_drug_source_drug_id
  on core.drug (tenant_id, source_system, source_drug_id)
  where source_drug_id is not null;
create index if not exists idx_payer_tenant_name on core.payer (tenant_id, payer_name);
create unique index if not exists uq_payer_source_id
  on core.payer (tenant_id, source_system, source_payer_id)
  where source_payer_id is not null;
create unique index if not exists uq_payer_bin_pcn_name
  on core.payer (
    tenant_id,
    source_system,
    coalesce(payer_bin, ''),
    coalesce(payer_pcn, ''),
    coalesce(payer_name, '')
  )
  where payer_bin is not null or payer_pcn is not null or payer_name is not null;
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
create index if not exists idx_canonical_drug on analytics.canonical_pharmacy_event (tenant_id, drug_id, business_date);
create index if not exists idx_event_payment_event on analytics.canonical_event_payer_payment (canonical_event_id);
create index if not exists idx_event_payment_payer on analytics.canonical_event_payer_payment (tenant_id, payer_id);
create unique index if not exists uq_event_payment_sequence
  on analytics.canonical_event_payer_payment (
    canonical_event_id,
    payment_type,
    coalesce(payer_sequence, '')
  );

-- Recommended access model:
-- 1. Ingestion/processor service role can write ops.*, safe core lookup rows, and analytics event/payment rows.
-- 2. API enrichment service role can read ops.source_prescription_reference_restricted.
-- 3. Dashboard/analytics role should read analytics.* plus safe core lookup labels only.
-- 4. Raw payload archive references point to restricted encrypted object storage; raw JSON should not be copied into analytics tables.
