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
| Public endpoint | Disabled |

The RDS instance should not be used directly by application services or local developer tools. Use RDS Proxy for application connections and SSM port forwarding for local pgAdmin/psql access.

## RDS Proxy

| Field | Value |
| --- | --- |
| Proxy name | `analytical-rx-phase1-rds-proxy` |
| Proxy endpoint | `analytical-rx-phase1-rds-proxy.proxy-c6ry4mqo6ydb.us-east-1.rds.amazonaws.com` |
| Engine family | PostgreSQL |
| TLS required | Yes |
| Target status | `AVAILABLE` |
| IAM role | `analytical-rx-phase1-rds-proxy-role` |
| Credential secret | `analytical-rx/phase1/dev/postgres/app-rw` |

Lambda/ECS services should connect to the proxy endpoint, not the direct RDS endpoint.

## Schemas Created

| Schema | Purpose |
| --- | --- |
| `tenant_template` | Template/review schema from the checked-in SQL file. |
| `tenant_analyticalrx_dev` | Initial development tenant schema for team testing. |

Both schemas currently have 9 tables from `schemas/mvp_canonical_event_schema.sql`.

## Security Groups

| Security group | ID | Purpose |
| --- | --- | --- |
| `analytical-rx-phase1-db-sg` | `sg-0baa533faee336e7b` | Attached to RDS. Allows PostgreSQL only from the RDS Proxy security group. |
| `analytical-rx-phase1-rds-proxy-sg` | `sg-07b9975f425288f7f` | Attached to RDS Proxy. Allows PostgreSQL from app services and the SSM tunnel host. |
| `analytical-rx-phase1-app-sg` | `sg-05d7ea352dbbb1de8` | Attach this to Lambda/ECS/app services that need database access through RDS Proxy. |
| `analytical-rx-phase1-ssm-db-tunnel-sg` | `sg-063dbd4e747686437` | Attached to the SSM tunnel host. Has no inbound rules. |

Current access rules:

- RDS accepts TCP `5432` only from `analytical-rx-phase1-rds-proxy-sg`.
- RDS Proxy accepts TCP `5432` from `analytical-rx-phase1-app-sg`.
- RDS Proxy accepts TCP `5432` from `analytical-rx-phase1-ssm-db-tunnel-sg`.
- SSM tunnel host has no inbound rules.

Do not add changing developer public IP addresses to the database security group. Use SSM port forwarding for local access.

## SSM Tunnel Host

| Field | Value |
| --- | --- |
| Instance name | `analytical-rx-phase1-ssm-db-tunnel` |
| Instance ID | `i-0ee64eae7d8505bfc` |
| Private IP | `172.31.13.30` |
| Platform | Amazon Linux |
| IAM role | `analytical-rx-phase1-ssm-db-tunnel-role` |
| Instance profile | `analytical-rx-phase1-ssm-db-tunnel-profile` |

This instance exists only to provide Session Manager tunnel access. It should not expose SSH or any public inbound ports.

The IAM group `analytical-rx-developers-webhook` has an inline policy named `AnalyticalRxPhase1DevDatabaseAccess` that allows:

- Reading the app database secret.
- Starting an SSM port forwarding session to the tunnel host.
- Describing the relevant RDS/SSM/EC2 resources.

## Local pgAdmin / psql Access

Local access flow:

```text
Developer laptop
  -> AWS SSM Session Manager tunnel
  -> analytical-rx-phase1-ssm-db-tunnel
  -> RDS Proxy
  -> RDS PostgreSQL
```

Prerequisites:

- AWS CLI configured with an IAM user in `analytical-rx-developers-webhook`.
- Session Manager plugin installed locally.
- Permission to read `analytical-rx/phase1/dev/postgres/app-rw`.

## Create AWS Access Key For Local Setup

Each teammate needs AWS CLI credentials for an IAM user that belongs to `analytical-rx-developers-webhook`.

Create the access key from AWS Console:

1. Sign in to the AnalyticalRx AWS account: `209556026827`.
2. Open **IAM**.
3. Go to **Users**.
4. Select your IAM user.
5. Open the **Security credentials** tab.
6. In **Access keys**, click **Create access key**.
7. Select **Command Line Interface (CLI)** as the use case.
8. Confirm the recommendation acknowledgement.
9. Click **Create access key**.
10. Copy the **Access key** and **Secret access key** immediately. The secret is shown only once.

Create a local `.env` file in the repository root:

```text
AWS_ACCESS_KEY=YOUR_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

Do not commit `.env`. It is already ignored by git.

The Windows tunnel script also supports the standard AWS variable name `AWS_ACCESS_KEY_ID` if a developer prefers that instead of `AWS_ACCESS_KEY`.

## Windows One-Shot Tunnel Script

Windows users can use this script:

```powershell
.\operations\start-phase1-db-tunnel.ps1 -EnvFile .env
```

What it does:

- Loads AWS credentials from `.env`.
- Clears any stale `AWS_PROFILE` value for this PowerShell process.
- Sets region to `us-east-1`.
- Verifies the AWS account is `209556026827`.
- Fetches the database connection secret from Secrets Manager.
- Copies the database password to the Windows clipboard by default.
- Prints pgAdmin connection settings.
- Starts the SSM tunnel on local port `5433`.

If PowerShell blocks local scripts, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\operations\start-phase1-db-tunnel.ps1 -EnvFile .env
```

Optional flags:

```powershell
.\operations\start-phase1-db-tunnel.ps1 -EnvFile .env -LocalPort 5434
.\operations\start-phase1-db-tunnel.ps1 -EnvFile .env -ShowPassword
.\operations\start-phase1-db-tunnel.ps1 -EnvFile .env -CopyPasswordToClipboard:$false
```

Keep the PowerShell window open while using pgAdmin or psql. Closing the PowerShell window closes the tunnel.

After the script starts, pgAdmin should use:

| Setting | Value |
| --- | --- |
| Host | `localhost` |
| Port | `5433` |
| Maintenance database | `analyticalrx` |
| Username | `analyticalrx_app_rw` |
| Password | Copied to clipboard by the script |
| SSL mode | `Require` |

## Manual Tunnel Command

Verify that the local AWS CLI is using the AnalyticalRx AWS account and region before starting the tunnel:

```bash
aws sts get-caller-identity
aws configure get region
```

Expected values:

- Account: `209556026827`
- Region: `us-east-1`

If the command shows a different account or region, switch to the correct AWS profile before continuing. Example:

```bash
export AWS_PROFILE=analyticalrx-dev
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
aws sts get-caller-identity
```

If using the repository `.env` temporarily, map the local variable names to AWS CLI variable names:

```bash
set -a
source .env
set +a
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
aws sts get-caller-identity
```

Start the tunnel:

```bash
aws ssm start-session \
  --target i-0ee64eae7d8505bfc \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["analytical-rx-phase1-rds-proxy.proxy-c6ry4mqo6ydb.us-east-1.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["5433"]}'
```

Keep that terminal open while using pgAdmin or psql.

pgAdmin connection settings:

| Setting | Value |
| --- | --- |
| Host | `localhost` |
| Port | `5433` |
| Maintenance database | `analyticalrx` |
| Username | From `analytical-rx/phase1/dev/postgres/app-rw` |
| Password | From `analytical-rx/phase1/dev/postgres/app-rw` |
| SSL mode | `Require` |

## Credentials

Do not use or share the RDS master password for normal application development.

Use the app-level read/write secret:

| Field | Value |
| --- | --- |
| Secret name | `analytical-rx/phase1/dev/postgres/app-rw` |
| Secret ARN | `arn:aws:secretsmanager:us-east-1:209556026827:secret:analytical-rx/phase1/dev/postgres/app-rw-nqJIXo` |
| Database user | `analyticalrx_app_rw` |
| Default schema | `tenant_analyticalrx_dev` |

The secret's `host` value points to the RDS Proxy endpoint. It also includes `rds_host`, `proxy_host`, `ssm_tunnel_instance_id`, and `recommended_local_port`.

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
- `proxy_host`
- `rds_host`
- `ssm_tunnel_instance_id`
- `recommended_local_port`

## Connect With psql

Start the SSM tunnel first. Then connect locally with SSL:

```bash
PGPASSWORD='PASSWORD_FROM_SECRET' psql \
  "host=localhost port=5433 dbname=analyticalrx user=analyticalrx_app_rw sslmode=require"
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
- Place the function/service in the same VPC/subnets as the database/proxy.
- Read the database connection secret from Secrets Manager.
- Connect to `analytical-rx-phase1-rds-proxy.proxy-c6ry4mqo6ydb.us-east-1.rds.amazonaws.com`.
- Connect with `sslmode=require`.
- Resolve tenant schema server-side from authenticated tenant context or trusted job configuration.
- Do not accept a schema name from frontend input or raw webhook payloads.

## Processor Lambda Current Configuration

The Phase 1 processor Lambda has been configured for the intended RDS Proxy path.

| Field | Value |
| --- | --- |
| Lambda function | `primeRx-webhook-processor` |
| Execution role | `primerx-processor-role-ykjld9us` |
| VPC | `vpc-009878654ad2bac42` |
| Subnets | `subnet-03f5fb7199efed202`, `subnet-0c885192fece53c98`, `subnet-0cea0eb252ebca70e` |
| Security group | `sg-05d7ea352dbbb1de8` / `analytical-rx-phase1-app-sg` |
| DB secret env var | `DB_SECRET_ID=analytical-rx/phase1/dev/postgres/app-rw` |
| Tenant schema env var | `DB_SCHEMA=tenant_analyticalrx_dev` |

Processor code should:

- Read `DB_SECRET_ID`.
- Fetch the secret from Secrets Manager.
- Use the secret's `host` value, which points to the RDS Proxy endpoint.
- Connect with PostgreSQL JDBC using `sslmode=require`.
- Set the schema from `DB_SCHEMA`.

Lambda execution role requirements:

- Basic Lambda logging permissions.
- VPC execution permissions, typically via `AWSLambdaVPCAccessExecutionRole`.
- `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret` for `analytical-rx/phase1/dev/postgres/app-rw`.
- `rds-db:connect` for `analyticalrx_app_rw` through the Phase 1 RDS Proxy.

Do not use the Lambda console direct RDS connection path for this processor. The console can create direct security groups such as `lambda-rds-1` and `rds-lambda-1`, which bypass the RDS Proxy. Those console-created security groups were removed after cleanup. The intended path is:

```text
primeRx-webhook-processor
  -> analytical-rx-phase1-app-sg
  -> analytical-rx-phase1-rds-proxy
  -> analytical-rx-phase1-db-sg
  -> analytical-rx-phase1-dev-db
```

## Operational Notes

- This database is for Phase 1 development only.
- Production PHI requires AWS BAA coverage, final security review, and production-grade backup/retention/access policies.
- The local `.env` currently uses root-level AWS credentials. Replace this with an IAM admin/deployment user or role before regular team operations.
