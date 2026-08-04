# Phase 1 AWS PostgreSQL Dev Database

Created: 2026-08-04  
AWS account: `209556026827`  
Region: `us-east-1`

This is the Phase 1 development PostgreSQL database for the webhook/canonical event work and starter dashboard backend development.

## RDS Instance

| Field | Value |
| --- | --- |
| DB instance identifier | `analytical-rx-phase1-dev-db` |
| Engine | PostgreSQL `17.10` |
| Instance class | `db.t4g.micro` |
| Database name | `analyticalrx` |
| Endpoint | `analytical-rx-phase1-dev-db.c6ry4mqo6ydb.us-east-1.rds.amazonaws.com` |
| Port | `5432` |
| Storage | `20 GB gp3`, encrypted |
| Backups | 7-day retention |
| Deletion protection | Enabled |
| Public endpoint | Enabled, but restricted by security group |

## Schemas Created

| Schema | Purpose |
| --- | --- |
| `tenant_template` | Template/review schema from the checked-in SQL file. |
| `tenant_analyticalrx_dev` | Initial development tenant schema for team testing. |

Both schemas currently have 9 tables from `schemas/mvp_canonical_event_schema.sql`.

## Security Groups

| Security group | ID | Purpose |
| --- | --- | --- |
| `analytical-rx-phase1-db-sg` | `sg-0baa533faee336e7b` | Attached to RDS. Allows PostgreSQL only from approved sources. |
| `analytical-rx-phase1-app-sg` | `sg-05d7ea352dbbb1de8` | Attach this to Lambda/ECS/app services that need database access. |

Current DB inbound access:

- TCP `5432` from Bhanu's current public IP: `124.123.132.215/32`.
- TCP `5432` from `analytical-rx-phase1-app-sg`.

If a developer needs direct local access, add only that person's current public IP as `/32`. Do not open PostgreSQL to `0.0.0.0/0`.

Example:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-0baa533faee336e7b \
  --protocol tcp \
  --port 5432 \
  --cidr YOUR_PUBLIC_IP/32
```

## Credentials

Do not use or share the RDS master password for normal application development.

Use the app-level read/write secret:

| Field | Value |
| --- | --- |
| Secret name | `analytical-rx/phase1/dev/postgres/app-rw` |
| Secret ARN | `arn:aws:secretsmanager:us-east-1:209556026827:secret:analytical-rx/phase1/dev/postgres/app-rw-nqJIXo` |
| Database user | `analyticalrx_app_rw` |
| Default schema | `tenant_analyticalrx_dev` |

The IAM group `analytical-rx-developers-webhook` has an inline policy named `AnalyticalRxPhase1DevPostgresSecretRead` that allows reading this secret.

## Fetch The Connection Secret

```bash
aws secretsmanager get-secret-value \
  --secret-id analytical-rx/phase1/dev/postgres/app-rw \
  --query SecretString \
  --output text
```

The secret JSON contains:

- `engine`
- `host`
- `port`
- `dbname`
- `username`
- `password`
- `sslmode`
- `default_schema`

## Connect With psql

After retrieving the secret, connect with SSL:

```bash
PGPASSWORD='PASSWORD_FROM_SECRET' psql \
  "host=analytical-rx-phase1-dev-db.c6ry4mqo6ydb.us-east-1.rds.amazonaws.com port=5432 dbname=analyticalrx user=analyticalrx_app_rw sslmode=require"
```

Use the development tenant schema:

```sql
set search_path to tenant_analyticalrx_dev, public;
select table_schema, count(*)
from information_schema.tables
where table_schema in ('tenant_template', 'tenant_analyticalrx_dev')
group by table_schema
order by table_schema;
```

## Application Access

For AWS Lambda/ECS/app services:

- Attach `analytical-rx-phase1-app-sg` to the compute service.
- Read the database connection secret from Secrets Manager.
- Connect with `sslmode=require`.
- Resolve tenant schema server-side from authenticated tenant context or trusted job configuration.
- Do not accept a schema name from frontend input or raw webhook payloads.

## Operational Notes

- This database is for Phase 1 development only.
- Production PHI requires AWS BAA coverage, final security review, and production-grade backup/retention/access policies.
- The local `.env` currently uses root-level AWS credentials. Replace this with an IAM admin/deployment user or role before regular team operations.
