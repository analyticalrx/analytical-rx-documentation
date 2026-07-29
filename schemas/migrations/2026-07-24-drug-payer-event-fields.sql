-- AnalyticalRx MVP canonical event schema migration.
-- Purpose: add normalized drug/payer tables, payer payment rows, and additional safe prescription event fields.

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

alter table analytics.canonical_pharmacy_event
  add column if not exists drug_id uuid references core.drug(id),
  add column if not exists date_ordered timestamptz,
  add column if not exists date_filled timestamptz,
  add column if not exists date_dispensed timestamptz,
  add column if not exists date_picked_up timestamptz,
  add column if not exists picked_up_flag boolean,
  add column if not exists days_supply integer,
  add column if not exists auth_refills integer,
  add column if not exists total_refills integer,
  add column if not exists quantity_ordered numeric(12,3),
  add column if not exists quantity_dispensed numeric(12,3),
  add column if not exists quantity_remaining numeric(12,3),
  add column if not exists order_status text,
  add column if not exists refill_queue_status text,
  add column if not exists verification_status text,
  add column if not exists label_printed_flag boolean,
  add column if not exists copay_collected_flag boolean,
  add column if not exists delivery_method text,
  add column if not exists bill_type text,
  add column if not exists rx_origin_code text,
  add column if not exists rx_origin_description text,
  add column if not exists ingredient_cost_amount numeric(12,2),
  add column if not exists dispensing_fee_amount numeric(12,2),
  add column if not exists other_fee_amount numeric(12,2),
  add column if not exists other_amount numeric(12,2),
  add column if not exists tax_amount numeric(12,2),
  add column if not exists discount_amount numeric(12,2),
  add column if not exists amount_due numeric(12,2),
  add column if not exists enriched_at timestamptz;

alter table analytics.canonical_pharmacy_event
  drop constraint if exists canonical_pharmacy_event_canonical_event_type_check;

alter table analytics.canonical_pharmacy_event
  add constraint canonical_pharmacy_event_canonical_event_type_check
  check (
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

create index if not exists idx_canonical_drug on analytics.canonical_pharmacy_event (tenant_id, drug_id, business_date);
create index if not exists idx_event_payment_event on analytics.canonical_event_payer_payment (canonical_event_id);
create index if not exists idx_event_payment_payer on analytics.canonical_event_payer_payment (tenant_id, payer_id);
create unique index if not exists uq_event_payment_sequence
  on analytics.canonical_event_payer_payment (
    canonical_event_id,
    payment_type,
    coalesce(payer_sequence, '')
  );
