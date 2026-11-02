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

Developers connect directly to this private RDS endpoint through SSM port forwarding. The processor Lambda uses its dedicated IAM-authenticated RDS Proxy. The database remains private.

## RDS Proxy

| Field | Value |
| --- | --- |
| Proxy name | `processor-lambda-iam-auth-proxy` |
| Proxy endpoint | `processor-lambda-iam-auth-proxy.proxy-c6ry4mqo6ydb.us-east-1.rds.amazonaws.com` |
| Engine family | PostgreSQL |
| TLS required | Yes |
| Target status | `AVAILABLE` |
| IAM role | `processor-lambda-rds-connector-role` |
| Credential secret | `analytical-rx/phase1/dev/postgres/app-rw` |

The processor Lambda uses IAM authentication through this proxy. The former development proxy was retired on 2026-11-02 after direct SSM access was verified. Local tools use the private database endpoint through the tunnel.

## Schemas Created

| Schema | Purpose |
| --- | --- |
| `control_plane` | Shared non-PHI application metadata: users, roles, tenant registry, role assignments, and app audit. |
| `tenant_template` | Template/review schema from the checked-in SQL file. |
| `tenant_analyticalrx_dev` | Initial development tenant schema for team testing. |

`control_plane` has 8 tables from `schemas/control_plane_schema.sql`. Each tenant schema currently has 9 tables from `schemas/mvp_canonical_event_schema.sql`.

## Security Groups

| Security group | ID | Purpose |
| --- | --- | --- |
| `analytical-rx-phase1-db-sg` | `sg-0baa533faee336e7b` | Attached to RDS. Allows PostgreSQL from approved proxy security groups and the SSM tunnel host security group. |
| `analytical-rx-phase1-rds-proxy-sg` | `sg-07b9975f425288f7f` | Attached to RDS Proxy. Allows PostgreSQL from app services and the SSM tunnel host. |
| `analytical-rx-phase1-app-sg` | `sg-05d7ea352dbbb1de8` | Attach this to Lambda/ECS/app services that need database access through RDS Proxy. |
| `analytical-rx-phase1-ssm-db-tunnel-sg` | `sg-063dbd4e747686437` | Attached to the SSM tunnel host. Has no inbound rules. |

Current access rules:

- RDS accepts TCP `5432` from its approved proxy security groups and `sg-063dbd4e747686437` (the SSM tunnel host).
- RDS Proxy accepts TCP `5432` from `analytical-rx-phase1-app-sg`.
- Developer SSM tunnels go directly to private RDS; the processor proxy remains for Lambda traffic.
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

To use the lifecycle script below, an AWS administrator must grant the teammate the actions in [analyticalrx-phase1-db-lifecycle-policy.json](analyticalrx-phase1-db-lifecycle-policy.json). The policy limits start/stop permissions to this database and the SSM tunnel instance. Each teammate must use their own IAM identity and AWS CLI profile. Do not use root credentials or share credentials.

## Start Or Stop The Dev Database

The development environment also has an [automatic weekday schedule](dev-schedule/README.md):
startup at 8:30 am IST Monday–Friday, a readiness check at 9:15 am, and a guarded
shutdown check at 1:00 am daily. Use the commands below for access outside those hours.

From the `analytical-rx-documentation` repository root, run the cross-platform script with Python 3.10+ and AWS CLI v2. It manages only the named Phase 1 development database and SSM tunnel host:

```bash
python3 operations/phase1-db-lifecycle.py status --env-file .env
python3 operations/phase1-db-lifecycle.py start database --env-file .env
python3 operations/phase1-db-lifecycle.py start tunnel --env-file .env
python3 operations/phase1-db-lifecycle.py start all --env-file .env
python3 operations/phase1-db-lifecycle.py stop database --env-file .env
python3 operations/phase1-db-lifecycle.py stop tunnel --env-file .env
```

On Windows, use `py` in place of `python3`:

```powershell
py .\operations\phase1-db-lifecycle.py status --env-file .env
py .\operations\phase1-db-lifecycle.py start database --env-file .env
py .\operations\phase1-db-lifecycle.py start tunnel --env-file .env
py .\operations\phase1-db-lifecycle.py start all --env-file .env
py .\operations\phase1-db-lifecycle.py stop database --env-file .env
py .\operations\phase1-db-lifecycle.py stop tunnel --env-file .env
```

If credentials are already configured through the AWS CLI, omit `--env-file .env`. To select a named AWS CLI profile, add `--profile PROFILE_NAME` before or after the command.

`start all` starts the database and tunnel host, then waits for the database and the processor proxy target to become ready and for the tunnel's SSM agent to come online. `stop database` checks recent RDS Proxy connections and active SSM sessions, checks again after confirmation, and requires you to type `STOP SHARED DEV DATABASE`. `stop tunnel` refuses while an SSM session is active and requires a separate confirmation. There is no `stop all` command because the database and tunnel have different users and impacts.

Stopping the database interrupts every app, Lambda, and developer task that needs the database until it is started again. The checks only confirm recent observed usage; they cannot prevent a new request arriving immediately after the check. Coordinate a maintenance window with the team and stop it only when the shared dev environment is idle. The RDS Proxies cannot be paused; the script only reports their status and never deletes them. Stopped RDS databases automatically restart after seven days. Database storage, backups, and the provisioned RDS Proxies can continue to incur charges while the database is stopped. Stopping the tunnel host blocks local tunnel access; its auto-assigned public IPv4 address can change after restart.

## Local pgAdmin / psql Access

For teammate-facing setup instructions, start with [Teammate Guide: Connect pgAdmin To AnalyticalRx Phase 1 Database](teammate-rds-pgadmin-access-guide.md).

Local access flow:

```text
Developer laptop
  -> AWS SSM Session Manager tunnel
  -> analytical-rx-phase1-ssm-db-tunnel
  -> RDS PostgreSQL
```

Prerequisites:

- AWS CLI configured with an IAM user in `analytical-rx-developers-webhook`.
- Session Manager plugin installed locally.
- Permission to read `analytical-rx/phase1/dev/postgres/data-platform-password-rw`.

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
AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

Do not commit `.env`. It is already ignored by git.

The Windows tunnel script also supports the older local alias `AWS_ACCESS_KEY`, but new setup should use `AWS_ACCESS_KEY_ID`.

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
| Username | `analyticalrx_data_platform_password_rw` |
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

If the command shows a different account or region, clear any stale profile value and load the repository `.env` before continuing:

```bash
unset AWS_PROFILE
set -a
source .env
set +a
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
aws sts get-caller-identity
```

Start the tunnel:

```bash
aws ssm start-session \
  --target i-0ee64eae7d8505bfc \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["analytical-rx-phase1-dev-db.c6ry4mqo6ydb.us-east-1.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["5433"]}'
```

Keep that terminal open while using pgAdmin or psql.

pgAdmin connection settings:

| Setting | Value |
| --- | --- |
| Host | `localhost` |
| Port | `5433` |
| Maintenance database | `analyticalrx` |
| Username | From `analytical-rx/phase1/dev/postgres/data-platform-password-rw` |
| Password | From `analytical-rx/phase1/dev/postgres/data-platform-password-rw` |
| SSL mode | `Require` |

## Credentials

Do not use or share the RDS master password for normal application development.

Use the app-level read/write secret:

| Field | Value |
| --- | --- |
| Secret name | `analytical-rx/phase1/dev/postgres/data-platform-password-rw` |
| Secret ARN | `arn:aws:secretsmanager:us-east-1:209556026827:secret:analytical-rx/phase1/dev/postgres/data-platform-password-rw-2dgiyh` |
| Database user | `analyticalrx_data_platform_password_rw` |
| Default schema | `tenant_analyticalrx_dev` |

The developer secret's `host` points directly to the private RDS endpoint. Use `localhost:5433` from a laptop while the SSM tunnel is open.

## Fetch The Connection Secret

```bash
aws secretsmanager get-secret-value \
  --secret-id analytical-rx/phase1/dev/postgres/data-platform-password-rw \
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
- `rds_host`
- `ssm_tunnel_instance_id`
- `recommended_local_port`

## Connect With psql

Start the SSM tunnel first. Then connect locally with SSL:

```bash
PGPASSWORD='PASSWORD_FROM_SECRET' psql \
  "host=localhost port=5433 dbname=analyticalrx user=analyticalrx_data_platform_password_rw sslmode=require"
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

For the existing processor Lambda:

- Attach `analytical-rx-phase1-app-sg` to the compute service.
- Place the function/service in the same VPC/subnets as the database/proxy.
- Read the database connection secret from Secrets Manager.
- Connect to `processor-lambda-iam-auth-proxy.proxy-c6ry4mqo6ydb.us-east-1.rds.amazonaws.com`.
- Connect with `sslmode=require` and an IAM authentication token.
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
- Connect with PostgreSQL JDBC using an IAM token and `sslmode=require`.
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
  -> processor-lambda-iam-auth-proxy
  -> analytical-rx-phase1-db-sg
  -> analytical-rx-phase1-dev-db
```

## Operational Notes

- This database is for Phase 1 development only.
- Production PHI requires AWS BAA coverage, final security review, and production-grade backup/retention/access policies.
- The local `.env` currently uses root-level AWS credentials. Replace this with an IAM admin/deployment user or role before regular team operations.
