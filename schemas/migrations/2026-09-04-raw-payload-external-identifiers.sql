-- Historical migration: this was applied before
-- 2026-09-29-bigint-internal-ids.sql converted relational IDs to bigint.
-- Do not run this file against the current Phase 1 schema.
-- It records the earlier change that kept external source identifiers as text.

begin;

alter table ingestion_event
  drop constraint ingestion_event_raw_payload_archive_id_fkey;

alter table raw_payload_archive
  alter column id drop default,
  alter column id type uuid using id::uuid,
  alter column id set default gen_random_uuid();

alter table ingestion_event
  alter column raw_payload_archive_id type uuid using raw_payload_archive_id::uuid;

alter table ingestion_event
  add constraint ingestion_event_raw_payload_archive_id_fkey
  foreign key (raw_payload_archive_id) references raw_payload_archive(id);

alter table raw_payload_archive
  add column message_id text not null,
  add column source_pharmacy_id text,
  add constraint raw_payload_archive_message_id_key unique (message_id);

commit;
