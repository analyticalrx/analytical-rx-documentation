-- AnalyticalRx MVP canonical event schema cleanup.
-- Purpose: remove duplicate drug/payer snapshots from canonical tables after normalizing drug and payer data.

drop index if exists idx_canonical_primary_payer;

alter table analytics.canonical_pharmacy_event
  drop column if exists primary_payer_id,
  drop column if exists source_drug_id,
  drop column if exists drug_ndc,
  drop column if exists drug_name,
  drop column if exists drug_generic_name,
  drop column if exists drug_strength,
  drop column if exists drug_form,
  drop column if exists drug_manufacturer_name,
  drop column if exists drug_class,
  drop column if exists drug_lot_no,
  drop column if exists drug_expiry_date,
  drop column if exists payer_type,
  drop column if exists payer_name,
  drop column if exists payer_bin,
  drop column if exists payer_pcn,
  drop column if exists insurance_paid_amount,
  drop column if exists patient_pay_amount,
  drop column if exists copay_paid_amount;

alter table analytics.canonical_event_payer_payment
  drop column if exists payer_name_snapshot,
  drop column if exists payer_bin_snapshot,
  drop column if exists payer_pcn_snapshot;
