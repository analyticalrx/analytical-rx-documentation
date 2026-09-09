-- AnalyticalRx Phase 1 control-plane schema.
-- Target database: PostgreSQL-compatible engine such as AWS RDS PostgreSQL or Aurora PostgreSQL.
-- Purpose: store shared non-PHI application metadata used for login, tenant routing, RBAC, and app audit.
--
-- Tenant-owned pharmacy/event data belongs in tenant schemas such as tenant_analyticalrx_dev.
-- Shared platform metadata belongs here, not in public and not inside each tenant schema.

create extension if not exists pgcrypto;

create schema if not exists control_plane;
set search_path to control_plane, public;

create table if not exists tenant_registry (
  id uuid primary key default gen_random_uuid(),
  tenant_key text not null,
  display_name text not null,
  schema_name text not null,
  status text not null default 'active' check (
    status in ('onboarding', 'active', 'inactive')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_key),
  unique (schema_name),
  check (tenant_key ~ '^[a-z0-9][a-z0-9-]*[a-z0-9]$'),
  check (schema_name ~ '^tenant_[a-z0-9_]+$')
);

create table if not exists app_user (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  display_name text not null,
  password_hash text not null,
  password_algorithm text not null default 'bcrypt',
  status text not null default 'active' check (
    status in ('invited', 'active', 'inactive', 'password_reset_required')
  ),
  permissions_version integer not null default 1 check (permissions_version > 0),
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uq_app_user_email_lower
  on app_user (lower(email));

create table if not exists role_definition (
  role_code text primary key,
  display_name text not null,
  description text not null,
  role_level text not null check (role_level in ('tenant', 'pharmacy', 'platform')),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into role_definition (role_code, display_name, description, role_level)
values
  ('OWNER_EXECUTIVE', 'Owner / Executive', 'Tenant-level business owner or executive with cross-store visibility.', 'tenant'),
  ('STORE_MANAGER', 'Store Manager', 'Pharmacy-level manager responsible for assigned store operations.', 'pharmacy'),
  ('PHARMACIST', 'Pharmacist', 'Pharmacy-level clinical and fulfillment workflow user.', 'pharmacy'),
  ('TECHNICIAN', 'Technician', 'Pharmacy-level operations user with limited workflow actions.', 'pharmacy'),
  ('BOOKKEEPER_FINANCE', 'Bookkeeper / Finance', 'Finance user for payment, revenue, reconciliation, and close visibility.', 'tenant'),
  ('COMPLIANCE_ADMIN', 'Compliance Admin', 'Compliance user for documents, licenses, compliance status, and audit visibility.', 'tenant'),
  ('BUSINESS_DEVELOPMENT', 'Business Development', 'Doctor office and relationship management user.', 'tenant'),
  ('TENANT_ADMIN', 'Tenant Admin', 'Customer-side administrator for tenant users, role assignments, and tenant settings.', 'tenant'),
  ('INTERNAL_PLATFORM_ADMIN', 'Internal Platform Admin', 'AnalyticalRx internal administrator for cross-tenant platform operations.', 'platform')
on conflict (role_code) do update
set
  display_name = excluded.display_name,
  description = excluded.description,
  role_level = excluded.role_level,
  updated_at = now();

create table if not exists user_tenant_access (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app_user(id),
  tenant_id uuid not null references tenant_registry(id),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, tenant_id)
);

create table if not exists user_role_assignment (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app_user(id),
  tenant_id uuid references tenant_registry(id),
  role_code text not null references role_definition(role_code),
  scope_type text not null check (
    scope_type in ('platform', 'tenant', 'all_pharmacies', 'selected_pharmacies')
  ),
  status text not null default 'active' check (status in ('active', 'inactive')),
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  created_by uuid references app_user(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from),
  check (
    (role_code = 'INTERNAL_PLATFORM_ADMIN' and tenant_id is null and scope_type = 'platform')
    or
    (role_code <> 'INTERNAL_PLATFORM_ADMIN' and tenant_id is not null and scope_type <> 'platform')
  )
);

create table if not exists user_role_pharmacy_scope (
  id uuid primary key default gen_random_uuid(),
  role_assignment_id uuid not null references user_role_assignment(id) on delete cascade,
  tenant_id uuid not null references tenant_registry(id),
  pharmacy_key text not null,
  created_at timestamptz not null default now(),
  unique (role_assignment_id, tenant_id, pharmacy_key)
);

create table if not exists permission_audit_event (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references app_user(id),
  target_user_id uuid references app_user(id),
  tenant_id uuid references tenant_registry(id),
  role_assignment_id uuid references user_role_assignment(id),
  action text not null,
  resource_type text,
  resource_id text,
  old_value jsonb,
  new_value jsonb,
  reason text,
  request_id text,
  created_at timestamptz not null default now()
);

create table if not exists app_access_audit_event (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references app_user(id),
  tenant_id uuid references tenant_registry(id),
  event_type text not null check (
    event_type in (
      'login_success',
      'login_failed',
      'logout',
      'token_issued',
      'token_rejected',
      'password_changed',
      'sensitive_read_denied',
      'admin_action'
    )
  ),
  resource_type text,
  resource_id text,
  status text not null default 'success' check (status in ('success', 'failure', 'denied')),
  request_id text,
  ip_address_hash text,
  user_agent_hash text,
  details jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_tenant_registry_status on tenant_registry (status);
create index if not exists idx_app_user_status on app_user (status);
create index if not exists idx_user_tenant_access_user on user_tenant_access (user_id, status);
create index if not exists idx_user_tenant_access_tenant on user_tenant_access (tenant_id, status);
create index if not exists idx_user_role_assignment_user on user_role_assignment (user_id, status);
create index if not exists idx_user_role_assignment_tenant_role on user_role_assignment (tenant_id, role_code, status);
create index if not exists idx_user_role_pharmacy_scope_assignment on user_role_pharmacy_scope (role_assignment_id);
create index if not exists idx_permission_audit_tenant_created on permission_audit_event (tenant_id, created_at);
create index if not exists idx_permission_audit_target_created on permission_audit_event (target_user_id, created_at);
create index if not exists idx_app_access_audit_user_created on app_access_audit_event (user_id, created_at);
create index if not exists idx_app_access_audit_tenant_created on app_access_audit_event (tenant_id, created_at);

insert into tenant_registry (tenant_key, display_name, schema_name, status)
values ('analyticalrx-dev', 'AnalyticalRx Dev Tenant', 'tenant_analyticalrx_dev', 'active')
on conflict (tenant_key) do update
set
  display_name = excluded.display_name,
  schema_name = excluded.schema_name,
  status = excluded.status,
  updated_at = now();

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'analyticalrx_app_rw') then
    grant usage on schema control_plane to analyticalrx_app_rw;
    grant select, insert, update, delete on all tables in schema control_plane to analyticalrx_app_rw;
    alter default privileges in schema control_plane
      grant select, insert, update, delete on tables to analyticalrx_app_rw;
  end if;
end $$;
