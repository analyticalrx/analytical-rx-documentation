-- Purpose: set the MVP default retention window for restricted raw payload archive metadata.
-- Legal/security should revisit this before production, but 30 days is the current MVP default.

alter table ops.raw_payload_archive
  alter column retention_until set default (current_date + 30);

update ops.raw_payload_archive
set retention_until = (received_at::date + 30)
where retention_until is null;

alter table ops.raw_payload_archive
  alter column retention_until set not null;
