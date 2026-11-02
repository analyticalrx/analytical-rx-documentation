# Teammate Guide: Connect pgAdmin To AnalyticalRx Phase 1 Database

Status: Team setup guide

Updated 2026-11-02: developer tunnels now connect directly to private RDS. If you
already registered pgAdmin, change its username to `analyticalrx_data_platform_password_rw`
and retrieve the password from `analytical-rx/phase1/dev/postgres/data-platform-password-rw`.
The host stays `localhost` and the port stays `5433`. Restart any old tunnel.

Audience: AnalyticalRx developers who need local pgAdmin access to the Phase 1 PostgreSQL database

## What This Setup Does

This setup lets you connect pgAdmin on your laptop to the private AWS RDS PostgreSQL database through AWS Systems Manager Session Manager.

Connection path:

```text
Your laptop
  -> AWS SSM tunnel
  -> AnalyticalRx tunnel EC2 instance
  -> RDS PostgreSQL
```

The database is not public. Do not ask to whitelist your home/office IP. Use this tunnel.

## Prerequisites

Before starting, confirm you have:

- Your own approved AWS IAM identity in the AnalyticalRx AWS account.
- Your identity added to the `analytical-rx-developers-webhook` group.
- Permission to read the database secret `analytical-rx/phase1/dev/postgres/data-platform-password-rw`.
- If you need to start or stop the shared database, the additional permissions in [analyticalrx-phase1-db-lifecycle-policy.json](analyticalrx-phase1-db-lifecycle-policy.json).
- Git repository cloned locally.
- AWS CLI v2 installed.
- AWS Session Manager Plugin installed.
- pgAdmin 4 installed.
- Python 3 installed if you want to manage the database or tunnel host.

Ask the AWS administrator if you do not have an IAM identity or group access. Do not use root credentials or another teammate's credentials.

## Step 1: Create AWS Access Key Credentials

Each developer needs AWS CLI credentials for their own IAM user.

1. Sign in to the AnalyticalRx AWS account.
2. Open **IAM**.
3. Go to **Users**.
4. Select your IAM user.
5. Open the **Security credentials** tab.
6. Scroll to **Access keys**.
7. Click **Create access key**.
8. Select **Command Line Interface (CLI)** as the use case.
9. Confirm the acknowledgement.
10. Click **Create access key**.
11. Copy the **Access key ID** and **Secret access key** immediately.

The secret access key is shown only once. Store it securely.

Do not use Bhanu's access key. Do not share your key with teammates. Do not paste access keys in Slack, GitHub, ChatGPT, email, screenshots, or documentation.

## Step 2: Create Local `.env`

In the documentation repository root, create a file named `.env`.

Example path:

```text
analytical-rx-documentation/.env
```

Add your AWS credentials:

```text
AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

Important:

- Do not add `AWS_PROFILE` to this file.
- Do not commit `.env`.
- `.env` is local-only and should stay ignored by git.

## Step 3: Install Required Tools

### AWS CLI

Install AWS CLI v2:

- Windows/macOS/Linux: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

Verify:

```bash
aws --version
```

### Session Manager Plugin

Install the AWS Session Manager Plugin:

- Windows/macOS/Linux: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

Verify:

```bash
session-manager-plugin
```

### pgAdmin

Install pgAdmin 4:

- https://www.pgadmin.org/download/

## Start Or Stop Shared Dev Resources

The [automatic development schedule](dev-schedule/README.md) starts resources at
8:30 am IST Monday–Friday and checks for shutdown at 1:00 am daily. Weekends have
no automatic startup. Use `start all` below when you need access outside those hours.

Ask an AWS administrator to attach [analyticalrx-phase1-db-lifecycle-policy.json](analyticalrx-phase1-db-lifecycle-policy.json) to your IAM identity or group first. It allows lifecycle actions only for the Phase 1 dev database and its SSM tunnel host.

From the `analytical-rx-documentation` directory, use these commands:

### Windows PowerShell

```powershell
py .\operations\phase1-db-lifecycle.py status --env-file .env
py .\operations\phase1-db-lifecycle.py start database --env-file .env
py .\operations\phase1-db-lifecycle.py start tunnel --env-file .env
py .\operations\phase1-db-lifecycle.py start all --env-file .env
py .\operations\phase1-db-lifecycle.py stop database --env-file .env
py .\operations\phase1-db-lifecycle.py stop tunnel --env-file .env
```

### macOS / Linux

```bash
python3 operations/phase1-db-lifecycle.py status --env-file .env
python3 operations/phase1-db-lifecycle.py start database --env-file .env
python3 operations/phase1-db-lifecycle.py start tunnel --env-file .env
python3 operations/phase1-db-lifecycle.py start all --env-file .env
python3 operations/phase1-db-lifecycle.py stop database --env-file .env
python3 operations/phase1-db-lifecycle.py stop tunnel --env-file .env
```

If AWS CLI credentials are already configured, omit `--env-file .env`. Add `--profile PROFILE_NAME` to use a named AWS CLI profile. The script checks the AWS account, waits for the requested state, and refuses to run as the AWS root user. The policy grants actions only for this database and tunnel instance.

Use `start all` to start both the database and tunnel host. The script waits until the database and the processor RDS Proxy target are ready, then waits for the tunnel's SSM agent. Use `start database` or `start tunnel` when you only need one resource. `status` shows both resources and the processor proxy target state, and active tunnel sessions.

Only stop a shared resource after coordinating with the team. `stop database` checks recent proxy usage and active SSM sessions, then asks you to type `STOP SHARED DEV DATABASE`. Stopping it interrupts database-backed API and Lambda work, as well as teammate database access, until someone starts it again. The checks are a snapshot and cannot guarantee that new work will not arrive, so use this only during an agreed idle period. `stop tunnel` checks for active SSM sessions and uses its own confirmation. There is no `stop all` option. RDS Proxies have no pause operation, and the script will not delete them; proxy charges continue while the database is stopped.

RDS restarts a stopped database automatically after seven days. Database storage and backups continue to incur charges. Stopping the tunnel host may change its auto-assigned public IPv4 address, but teammates connect through SSM and do not need to use that address.

## Step 4: Start The Database Tunnel

The database and tunnel host must be running before you connect. If needed, use
`start all` under **Start Or Stop Shared Dev Resources** and wait for it to report
that the processor proxy target and the SSM agent are ready.

Keep the tunnel terminal open while using pgAdmin. Closing the terminal closes the database connection.

### Windows PowerShell

From the repository root:

```powershell
.\operations\start-phase1-db-tunnel.ps1 -EnvFile .env
```

If PowerShell blocks local scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\operations\start-phase1-db-tunnel.ps1 -EnvFile .env
```

The script will:

- Load AWS credentials from `.env`.
- Ignore any stale `AWS_PROFILE` for this terminal session.
- Verify the AWS account.
- Fetch the database username/password from Secrets Manager.
- Copy the database password to your clipboard.
- Print pgAdmin connection settings.
- Start the SSM tunnel on local port `5433`.

If port `5433` is already in use:

```powershell
.\operations\start-phase1-db-tunnel.ps1 -EnvFile .env -LocalPort 5434
```

Then use port `5434` in pgAdmin.

### macOS / Linux

Install the AWS CLI v2 and Session Manager Plugin first. From the repository root,
run:

```bash
bash operations/start-phase1-db-tunnel.sh
```

Keep this terminal open while using pgAdmin. The script checks that you are in
AWS account `209556026827` before opening the tunnel. Press Ctrl+C to close it.

To get the database password, open **AWS Console → Secrets Manager**, select
`analytical-rx/phase1/dev/postgres/data-platform-password-rw`, and choose **Retrieve secret value**.
Copy the `password` value into pgAdmin. Do not paste the whole secret JSON into
a terminal.

## Step 5: Add Server In pgAdmin

Open pgAdmin and register a new server.

### General Tab

| Field | Value |
| --- | --- |
| Name | `AnalyticalRx Phase 1 Dev` |

### Connection Tab

| Field | Value |
| --- | --- |
| Host name/address | `localhost` |
| Port | `5433` |
| Maintenance database | `analyticalrx` |
| Username | `analyticalrx_data_platform_password_rw` |
| Password | `password` value from the `data-platform-password-rw` secret (Windows script copies it) |
| Save password | Optional |

If you started the tunnel with another local port, use that port instead of `5433`.

### SSL Tab

| Field | Value |
| --- | --- |
| SSL mode | `Require` |

Click **Save**.

## Step 6: Confirm The Database Is Visible

In pgAdmin, open:

```text
Servers
  -> AnalyticalRx Phase 1 Dev
  -> Databases
  -> analyticalrx
  -> Schemas
```

You should see:

```text
control_plane
tenant_template
tenant_analyticalrx_dev
```

The main development tenant schema is:

```text
tenant_analyticalrx_dev
```

## Step 7: Optional psql Test

After the tunnel is running:

```bash
psql "host=localhost port=5433 dbname=analyticalrx user=analyticalrx_data_platform_password_rw sslmode=require" -W
```

`psql` asks for the password without putting it in the command or shell history.

Then run:

```sql
set search_path to tenant_analyticalrx_dev, public;

select table_name
from information_schema.tables
where table_schema = 'tenant_analyticalrx_dev'
order by table_name;
```

Expected tables include:

```text
drug
event_payment
ingestion_event
payer
pharmacy
pharmacy_event
raw_payload_archive
source_rx_reference
tenant
```

The shared app/auth metadata tables are in:

```text
control_plane
```

## Troubleshooting

### Error: The config profile could not be found

Remove `AWS_PROFILE=...` from `.env`. The tunnel script uses the access key in
`.env` for this terminal.

### Error: Wrong AWS account

Both tunnel scripts check for AWS account `209556026827` before connecting. If
the check fails, confirm that `.env` contains your AnalyticalRx access key and
secret access key.

### Error: AccessDenied for `ssm:StartSession`

Your IAM user is missing Session Manager tunnel permissions.

Ask Bhanu to confirm:

- Your IAM user is in `analytical-rx-developers-webhook`.
- The group has the Phase 1 database access policy.
- You are using the correct AWS access key for that user.

### Error: AccessDenied for Secrets Manager

Your IAM user cannot read the database connection secret.

Ask Bhanu to confirm access to:

```text
analytical-rx/phase1/dev/postgres/data-platform-password-rw
```

### Error: Session Manager Plugin is not found

Install the plugin and restart your terminal.

Verify:

```bash
session-manager-plugin
```

### Error: pgAdmin cannot connect

Check:

- The SSM tunnel terminal is still open.
- pgAdmin host is `localhost`.
- pgAdmin port matches the local tunnel port.
- SSL mode is `Require`.
- Username is `analyticalrx_data_platform_password_rw`.
- Password is copied from Secrets Manager, not your AWS secret key.

### Error: Local port already in use

Use a different local port.

Windows:

```powershell
.\operations\start-phase1-db-tunnel.ps1 -EnvFile .env -LocalPort 5434
```

macOS/Linux:

Pass `5434` as the second argument:

```bash
bash operations/start-phase1-db-tunnel.sh .env 5434
```

Then use port `5434` in pgAdmin.

## Security Rules

- Use your own IAM access key only.
- Do not commit `.env`.
- Do not paste secrets into chat, tickets, screenshots, or docs.
- Do not share the database password outside approved setup steps.
- Do not use the RDS master password for development.
- Do not expose RDS publicly.
- Do not add personal IP addresses to database security groups.
- Rotate your AWS access key if it is ever exposed.

## Reference Values

| Item | Value |
| --- | --- |
| AWS account ID | `209556026827` |
| AWS region | `us-east-1` |
| RDS database name | `analyticalrx` |
| Private RDS endpoint | `analytical-rx-phase1-dev-db.c6ry4mqo6ydb.us-east-1.rds.amazonaws.com` |
| SSM tunnel instance ID | `i-0ee64eae7d8505bfc` |
| Local tunnel port | `5433` |
| Database user | `analyticalrx_data_platform_password_rw` |
| Database secret name | `analytical-rx/phase1/dev/postgres/data-platform-password-rw` |
| Main dev tenant schema | `tenant_analyticalrx_dev` |
