-- Purpose: set the MVP default retention window for restricted raw payload archive metadata.
-- Legal/security should revisit this before production, but 30 days is the current MVP default.
-- Tenant schema model: run inside the target tenant schema. tenant_template is the local review schema.

create schema if not exists tenant_template;
set search_path to tenant_template, public;

alter table raw_payload_archive
  alter column retention_until set default (current_date + 30);

update raw_payload_archive
set retention_until = (received_at::date + 30)
where retention_until is null;

alter table raw_payload_archive
  alter column retention_until set not null;
