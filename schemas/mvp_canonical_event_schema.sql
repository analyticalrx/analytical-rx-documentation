-- AnalyticalRx MVP canonical event schema draft.
-- Target database: PostgreSQL-compatible engine such as AWS RDS PostgreSQL or Aurora PostgreSQL.
-- Purpose: store PrimeRx webhook/API events safely inside one tenant-owned schema.
-- SaaS isolation decision: create one PostgreSQL schema per tenant and create all tenant data tables inside that schema.
-- This design file uses tenant_template as the review/template schema. In production, replace it with the tenant schema name,
-- for example tenant_acme_pharmacy_group.

create extension if not exists pgcrypto;

create schema if not exists tenant_template;
set search_path to tenant_template, public;

create table if not exists tenant (
  id uuid primary key default gen_random_uuid(),
  tenant_key text not null unique,
  display_name text not null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists pharmacy (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenant(id),
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

create table if not exists drug (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenant(id),
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

create table if not exists payer (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenant(id),
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

create table if not exists raw_payload_archive (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenant(id),
  pharmacy_id uuid references pharmacy(id),
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

create table if not exists source_rx_reference (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenant(id),
  pharmacy_id uuid not null references pharmacy(id),
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

create table if not exists ingestion_event (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenant(id),
  pharmacy_id uuid references pharmacy(id),
  source_system text not null,
  source_event_id text,
  source_event_type text not null,
  receiver_request_id text,
  idempotency_key text not null,
  source_rx_reference_id uuid references source_rx_reference(id),
  raw_payload_archive_id uuid references raw_payload_archive(id),
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
  duplicate_of uuid references ingestion_event(id),
  failure_code text,
  failure_reason text,
  schema_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, source_system, idempotency_key)
);

create table if not exists pharmacy_event (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenant(id),
  pharmacy_id uuid not null references pharmacy(id),
  ingestion_event_id uuid not null unique references ingestion_event(id),
  drug_id uuid references drug(id),
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

create table if not exists event_payment (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenant(id),
  pharmacy_id uuid not null references pharmacy(id),
  pharmacy_event_id uuid not null references pharmacy_event(id) on delete cascade,
  payer_id uuid references payer(id),
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

create index if not exists idx_pharmacy_tenant on pharmacy (tenant_id);
create unique index if not exists uq_pharmacy_source_id
  on pharmacy (tenant_id, source_system, (coalesce(source_pharmacy_id, '')));
create index if not exists idx_drug_tenant_name on drug (tenant_id, drug_name);
create unique index if not exists uq_drug_source_ndc
  on drug (tenant_id, source_system, ndc)
  where ndc is not null;
create unique index if not exists uq_drug_source_drug_id
  on drug (tenant_id, source_system, source_drug_id)
  where source_drug_id is not null;
create index if not exists idx_payer_tenant_name on payer (tenant_id, payer_name);
create unique index if not exists uq_payer_source_id
  on payer (tenant_id, source_system, source_payer_id)
  where source_payer_id is not null;
create unique index if not exists uq_payer_bin_pcn_name
  on payer (
    tenant_id,
    source_system,
    coalesce(payer_bin, ''),
    coalesce(payer_pcn, ''),
    coalesce(payer_name, '')
  )
  where payer_bin is not null or payer_pcn is not null or payer_name is not null;
create index if not exists idx_raw_payload_tenant_received on raw_payload_archive (tenant_id, received_at);
create index if not exists idx_source_rx_ref_prescription_token on source_rx_reference (tenant_id, prescription_reference_token);
create index if not exists idx_source_rx_ref_fill_token on source_rx_reference (tenant_id, fill_reference_token);
create unique index if not exists uq_source_rx_ref_rx_fill
  on source_rx_reference (tenant_id, pharmacy_id, source_system, rx_no, (coalesce(refill_no, '')));
create index if not exists idx_source_rx_ref_rx on source_rx_reference (tenant_id, pharmacy_id, source_system, rx_no, refill_no);
create index if not exists idx_ingestion_event_status_received on ingestion_event (tenant_id, status, received_at);
create index if not exists idx_ingestion_event_source_type on ingestion_event (tenant_id, source_system, source_event_type, received_at);
create index if not exists idx_pharmacy_event_business_date on pharmacy_event (tenant_id, pharmacy_id, business_date);
create index if not exists idx_pharmacy_event_type on pharmacy_event (tenant_id, canonical_event_type, business_date);
create index if not exists idx_pharmacy_event_fill_token on pharmacy_event (tenant_id, fill_reference_token);
create index if not exists idx_pharmacy_event_drug on pharmacy_event (tenant_id, drug_id, business_date);
create index if not exists idx_event_payment_event on event_payment (pharmacy_event_id);
create index if not exists idx_event_payment_payer on event_payment (tenant_id, payer_id);
create unique index if not exists uq_event_payment_sequence
  on event_payment (
    pharmacy_event_id,
    payment_type,
    coalesce(payer_sequence, '')
  );

-- Recommended access model:
-- 1. Ingestion/processor service role can write ingestion/source-reference rows, safe lookup rows, and event/payment rows inside the tenant schema.
-- 2. API enrichment service role can read source_rx_reference.
-- 3. Dashboard role should read only dashboard-safe tables/views inside the selected tenant schema.
-- 4. Raw payload archive references point to restricted encrypted object storage; raw JSON should not be copied into canonical dashboard tables.
-- 5. The application must choose the tenant schema from authenticated tenant context, never from untrusted request parameters.
