-- Dev tenant task tables. Run as a database admin after reviewing role grants below.
begin;

create table if not exists tenant_analyticalrx_dev.task (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references tenant_analyticalrx_dev.tenant(id),
  pharmacy_key text not null,
  title text not null check (length(trim(title)) between 1 and 200),
  description text,
  status text not null default 'TODO' check (status in ('TODO', 'IN_PROGRESS', 'BLOCKED', 'COMPLETED', 'SKIPPED', 'CANCELED')),
  priority text not null default 'MEDIUM' check (priority in ('LOW', 'MEDIUM', 'HIGH', 'URGENT')),
  due_at timestamptz,
  assignee_user_id bigint not null,
  created_by_user_id bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (id, tenant_id),
  foreign key (tenant_id, pharmacy_key)
    references tenant_analyticalrx_dev.pharmacy(tenant_id, pharmacy_key),
  foreign key (assignee_user_id, tenant_id)
    references control_plane.app_user(id, tenant_id),
  foreign key (created_by_user_id, tenant_id)
    references control_plane.app_user(id, tenant_id)
);

create index if not exists idx_task_pharmacy_status_due
  on tenant_analyticalrx_dev.task (tenant_id, pharmacy_key, status, due_at);
create index if not exists idx_task_assignee_status_due
  on tenant_analyticalrx_dev.task (tenant_id, assignee_user_id, status, due_at);

create table if not exists tenant_analyticalrx_dev.task_comment (
  id bigint generated always as identity primary key,
  tenant_id bigint not null,
  task_id bigint not null,
  author_user_id bigint not null,
  comment_text text not null check (length(trim(comment_text)) between 1 and 2000),
  created_at timestamptz not null default now(),
  foreign key (task_id, tenant_id) references tenant_analyticalrx_dev.task(id, tenant_id),
  foreign key (author_user_id, tenant_id) references control_plane.app_user(id, tenant_id)
);

create index if not exists idx_task_comment_task_created
  on tenant_analyticalrx_dev.task_comment (tenant_id, task_id, created_at desc);

create table if not exists tenant_analyticalrx_dev.task_activity (
  id bigint generated always as identity primary key,
  tenant_id bigint not null,
  task_id bigint not null,
  actor_user_id bigint not null,
  activity_type text not null check (activity_type in ('CREATED', 'STATUS_CHANGED', 'COMMENT_ADDED')),
  old_status text,
  new_status text,
  created_at timestamptz not null default now(),
  foreign key (task_id, tenant_id) references tenant_analyticalrx_dev.task(id, tenant_id),
  foreign key (actor_user_id, tenant_id) references control_plane.app_user(id, tenant_id)
);

create index if not exists idx_task_activity_task_created
  on tenant_analyticalrx_dev.task_activity (tenant_id, task_id, created_at desc);

insert into control_plane.permission_definition (permission_code, display_name, description)
values
  ('task.read', 'Read tasks', 'Read tasks within assigned pharmacy scope.'),
  ('task.create', 'Create tasks', 'Create tasks within assigned pharmacy scope.'),
  ('task.update', 'Update tasks', 'Change status of tasks within assigned pharmacy scope.'),
  ('task.comment', 'Comment on tasks', 'Add comments to visible tasks.')
on conflict (permission_code) do nothing;

insert into control_plane.role_permission (role_id, permission_id)
select r.id, p.id
from control_plane.role_definition r
join control_plane.permission_definition p on (r.role_code, p.permission_code) in (
  ('OWNER', 'task.read'), ('OWNER', 'task.create'), ('OWNER', 'task.update'), ('OWNER', 'task.comment'),
  ('STORE_MANAGER', 'task.read'), ('STORE_MANAGER', 'task.create'), ('STORE_MANAGER', 'task.update'), ('STORE_MANAGER', 'task.comment'),
  ('PHARMACIST', 'task.read'), ('PHARMACIST', 'task.create'), ('PHARMACIST', 'task.update'), ('PHARMACIST', 'task.comment'),
  ('TECHNICIAN', 'task.read'), ('TECHNICIAN', 'task.update'), ('TECHNICIAN', 'task.comment'),
  ('BOOKKEEPER', 'task.read'), ('BOOKKEEPER', 'task.create'), ('BOOKKEEPER', 'task.update'), ('BOOKKEEPER', 'task.comment'),
  ('BUSINESS_DEVELOPMENT', 'task.read'), ('BUSINESS_DEVELOPMENT', 'task.create'), ('BUSINESS_DEVELOPMENT', 'task.update'), ('BUSINESS_DEVELOPMENT', 'task.comment')
)
on conflict (role_id, permission_id) do nothing;

grant select, insert, update on tenant_analyticalrx_dev.task
  to analyticalrx_data_platform_password_rw;
grant select, insert on tenant_analyticalrx_dev.task_comment,
  tenant_analyticalrx_dev.task_activity to analyticalrx_data_platform_password_rw;
grant usage on sequence tenant_analyticalrx_dev.task_id_seq,
  tenant_analyticalrx_dev.task_comment_id_seq,
  tenant_analyticalrx_dev.task_activity_id_seq to analyticalrx_data_platform_password_rw;

commit;
