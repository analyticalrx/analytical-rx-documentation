-- AnalyticalRx MVP canonical event schema rename.
-- Purpose: rename early draft table names to simpler Phase 1 names without changing table structure.
-- Run once per tenant schema after taking a database backup.
--
-- Replace tenant_template with the target tenant schema, for example:
--   set search_path to tenant_analyticalrx_dev, public;

create schema if not exists tenant_template;
set search_path to tenant_template, public;

begin;

alter table if exists canonical_event_payer_payment rename to event_payment;
alter table if exists canonical_pharmacy_event rename to pharmacy_event;
alter table if exists webhook_event_audit rename to ingestion_event;
alter table if exists source_prescription_reference_restricted rename to source_rx_reference;

alter table if exists ingestion_event
  rename column source_reference_id to source_rx_reference_id;

alter table if exists pharmacy_event
  rename column audit_event_id to ingestion_event_id;

alter table if exists event_payment
  rename column canonical_event_id to pharmacy_event_id;

alter index if exists idx_source_ref_prescription_token rename to idx_source_rx_ref_prescription_token;
alter index if exists idx_source_ref_fill_token rename to idx_source_rx_ref_fill_token;
alter index if exists uq_source_ref_rx_fill rename to uq_source_rx_ref_rx_fill;
alter index if exists idx_source_ref_rx rename to idx_source_rx_ref_rx;
alter index if exists idx_audit_status_received rename to idx_ingestion_event_status_received;
alter index if exists idx_audit_source_type rename to idx_ingestion_event_source_type;
alter index if exists idx_canonical_business_date rename to idx_pharmacy_event_business_date;
alter index if exists idx_canonical_event_type rename to idx_pharmacy_event_type;
alter index if exists idx_canonical_fill_token rename to idx_pharmacy_event_fill_token;
alter index if exists idx_canonical_drug rename to idx_pharmacy_event_drug;

do $$
declare
  target_table text;
  old_constraint text;
  new_constraint text;
begin
  for target_table, old_constraint, new_constraint in
    select *
    from (
      values
        ('source_rx_reference', 'source_prescription_reference_restricted_pkey', 'source_rx_reference_pkey'),
        ('source_rx_reference', 'source_prescription_reference_restricted_tenant_id_fkey', 'source_rx_reference_tenant_id_fkey'),
        ('source_rx_reference', 'source_prescription_reference_restricted_pharmacy_id_fkey', 'source_rx_reference_pharmacy_id_fkey'),
        ('ingestion_event', 'webhook_event_audit_pkey', 'ingestion_event_pkey'),
        ('ingestion_event', 'webhook_event_audit_tenant_id_fkey', 'ingestion_event_tenant_id_fkey'),
        ('ingestion_event', 'webhook_event_audit_pharmacy_id_fkey', 'ingestion_event_pharmacy_id_fkey'),
        ('ingestion_event', 'webhook_event_audit_source_reference_id_fkey', 'ingestion_event_source_rx_reference_id_fkey'),
        ('ingestion_event', 'webhook_event_audit_raw_payload_archive_id_fkey', 'ingestion_event_raw_payload_archive_id_fkey'),
        ('ingestion_event', 'webhook_event_audit_duplicate_of_fkey', 'ingestion_event_duplicate_of_fkey'),
        ('ingestion_event', 'webhook_event_audit_status_check', 'ingestion_event_status_check'),
        ('ingestion_event', 'webhook_event_audit_phi_suppression_status_check', 'ingestion_event_phi_suppression_status_check'),
        ('ingestion_event', 'webhook_event_audit_tenant_id_source_system_idempotency_key_key', 'ingestion_event_tenant_id_source_system_idempotency_key_key'),
        ('pharmacy_event', 'canonical_pharmacy_event_pkey', 'pharmacy_event_pkey'),
        ('pharmacy_event', 'canonical_pharmacy_event_tenant_id_fkey', 'pharmacy_event_tenant_id_fkey'),
        ('pharmacy_event', 'canonical_pharmacy_event_pharmacy_id_fkey', 'pharmacy_event_pharmacy_id_fkey'),
        ('pharmacy_event', 'canonical_pharmacy_event_audit_event_id_fkey', 'pharmacy_event_ingestion_event_id_fkey'),
        ('pharmacy_event', 'canonical_pharmacy_event_audit_event_id_key', 'pharmacy_event_ingestion_event_id_key'),
        ('pharmacy_event', 'canonical_pharmacy_event_drug_id_fkey', 'pharmacy_event_drug_id_fkey'),
        ('pharmacy_event', 'canonical_pharmacy_event_canonical_event_type_check', 'pharmacy_event_canonical_event_type_check'),
        ('pharmacy_event', 'canonical_pharmacy_event_enrichment_status_check', 'pharmacy_event_enrichment_status_check'),
        ('pharmacy_event', 'canonical_pharmacy_event_data_quality_status_check', 'pharmacy_event_data_quality_status_check'),
        ('event_payment', 'canonical_event_payer_payment_pkey', 'event_payment_pkey'),
        ('event_payment', 'canonical_event_payer_payment_tenant_id_fkey', 'event_payment_tenant_id_fkey'),
        ('event_payment', 'canonical_event_payer_payment_pharmacy_id_fkey', 'event_payment_pharmacy_id_fkey'),
        ('event_payment', 'canonical_event_payer_payment_canonical_event_id_fkey', 'event_payment_pharmacy_event_id_fkey'),
        ('event_payment', 'canonical_event_payer_payment_payer_id_fkey', 'event_payment_payer_id_fkey'),
        ('event_payment', 'canonical_event_payer_payment_payment_type_check', 'event_payment_payment_type_check'),
        ('event_payment', 'canonical_event_payer_payment_payer_sequence_check', 'event_payment_payer_sequence_check')
    ) as constraint_renames(target_table, old_constraint, new_constraint)
  loop
    if exists (
      select 1
      from pg_constraint
      where conrelid = to_regclass(target_table)
        and conname = old_constraint
    ) then
      execute format(
        'alter table %I rename constraint %I to %I',
        target_table,
        old_constraint,
        new_constraint
      );
    end if;
  end loop;
end $$;

-- PostgreSQL 18 exposes generated NOT NULL constraints in pg_constraint.
-- Rename any remaining generated constraint/index metadata that still carries an old draft name.
do $$
declare
  constraint_record record;
  candidate_name text;
begin
  for constraint_record in
    select rel.relname as table_name, con.conname as constraint_name
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace ns on ns.oid = rel.relnamespace
    where ns.nspname = current_schema()
      and rel.relname in ('source_rx_reference', 'ingestion_event', 'pharmacy_event', 'event_payment')
  loop
    candidate_name := constraint_record.constraint_name;
    candidate_name := replace(candidate_name, 'source_prescription_reference_restricted', 'source_rx_reference');
    candidate_name := replace(candidate_name, 'source_prescription_reference', 'source_rx_reference');
    candidate_name := replace(candidate_name, 'source_prescription_referen', 'source_rx_reference');
    candidate_name := replace(candidate_name, 'webhook_event_audit', 'ingestion_event');
    candidate_name := replace(candidate_name, 'canonical_pharmacy_event', 'pharmacy_event');
    candidate_name := replace(candidate_name, 'canonical_event_payer_payment', 'event_payment');
    candidate_name := replace(candidate_name, 'source_reference_id', 'source_rx_reference_id');
    candidate_name := replace(candidate_name, 'audit_event_id', 'ingestion_event_id');
    candidate_name := replace(candidate_name, 'canonical_event_id', 'pharmacy_event_id');
    candidate_name := left(candidate_name, 63);

    if candidate_name <> constraint_record.constraint_name
      and not exists (
        select 1
        from pg_constraint con
        join pg_class rel on rel.oid = con.conrelid
        join pg_namespace ns on ns.oid = rel.relnamespace
        where ns.nspname = current_schema()
          and rel.relname = constraint_record.table_name
          and con.conname = candidate_name
      )
    then
      execute format(
        'alter table %I rename constraint %I to %I',
        constraint_record.table_name,
        constraint_record.constraint_name,
        candidate_name
      );
    end if;
  end loop;
end $$;

do $$
declare
  index_record record;
  candidate_name text;
begin
  for index_record in
    select cls.relname as index_name
    from pg_class cls
    join pg_namespace ns on ns.oid = cls.relnamespace
    where ns.nspname = current_schema()
      and cls.relkind in ('i', 'I')
  loop
    candidate_name := index_record.index_name;
    candidate_name := replace(candidate_name, 'source_prescription_reference_restricted', 'source_rx_reference');
    candidate_name := replace(candidate_name, 'source_prescription_reference', 'source_rx_reference');
    candidate_name := replace(candidate_name, 'source_prescription_referen', 'source_rx_reference');
    candidate_name := replace(candidate_name, 'webhook_event_audit', 'ingestion_event');
    candidate_name := replace(candidate_name, 'canonical_pharmacy_event', 'pharmacy_event');
    candidate_name := replace(candidate_name, 'canonical_event_payer_payment', 'event_payment');
    candidate_name := replace(candidate_name, 'source_reference_id', 'source_rx_reference_id');
    candidate_name := replace(candidate_name, 'audit_event_id', 'ingestion_event_id');
    candidate_name := replace(candidate_name, 'canonical_event_id', 'pharmacy_event_id');
    candidate_name := left(candidate_name, 63);

    if candidate_name <> index_record.index_name
      and to_regclass(candidate_name) is null
    then
      execute format(
        'alter index %I rename to %I',
        index_record.index_name,
        candidate_name
      );
    end if;
  end loop;
end $$;

commit;
