# Phase 1 development schedule

AWS account `209556026827`, region `us-east-1`. CloudFormation stack:
`analyticalrx-phase1-dev-schedule`.

Activated on 2026-11-02. CloudFormation reached `CREATE_COMPLETE`; all three
schedules were read back as enabled in `Asia/Kolkata`. A deployed shutdown dry run
confirmed idle checks passed without stopping resources, and the deployed readiness
check confirmed the database, the processor proxy target, and SSM agent were ready.
The seven local safety tests also passed.

| Time (Asia/Kolkata / IST) | Action |
| --- | --- |
| 8:30 am, Monday–Friday | Request database and tunnel EC2 startup |
| 9:15 am, Monday–Friday | Check database availability, the processor proxy target, and SSM agent readiness |
| 1:00 am, every day | Check activity, then request database and tunnel shutdown if idle |

Weekends have no automatic startup. Friday's workday ends with the Saturday
1:00 am shutdown. Anyone with the lifecycle policy can start the resources
outside these hours. Startup is asynchronous; 8:30 am is the request time,
not a guarantee of readiness. RDS startup can take longer during recovery.

## What is controlled

- RDS database: `analytical-rx-phase1-dev-db`
- SSM tunnel EC2: `i-0ee64eae7d8505bfc`
- The processor IAM-auth proxy is preserved. The development proxy was retired; developer access goes directly to private RDS through SSM.

The Scheduler invokes the `analyticalrx-phase1-dev-schedule` Lambda using a
role limited to that function. The Lambda has lifecycle permissions only for
the fixed database and tunnel host. It uses its execution role, with no shared
access keys. The deployment identity is not used for scheduled runs.

## Shutdown checks

An active SSM session cancels the entire shutdown. When the database is available,
the processor proxy must report zero `ClientConnections` in every minute of a completed
15-minute window ending two minutes ago. Missing data or AWS API errors prevent
shutdown. A second SSM session check runs immediately before the lifecycle calls.

These checks observe recent usage; CloudWatch has publication delay and cannot
lock out a new request. The environment intentionally becomes unavailable outside
working hours. Do not schedule overnight integrations, demos, or webhook tests
against it while stopped. Incoming webhook processing can fail/retry or reach its
queue's dead-letter limit while the database is offline.

A skipped shutdown leaves resources running until a manual stop or the next
night's check. A stopped resource is a no-op. The scheduler never force-stops EC2
or deletes proxies. RDS restarts automatically after seven days stopped; normal
weekday startup happens before that limit.

## Working outside scheduled hours

From the documentation repository root, with your own IAM credentials:

Windows:

```powershell
py .\operations\phase1-db-lifecycle.py start all --env-file .env
py .\operations\phase1-db-lifecycle.py status --env-file .env
```

macOS/Linux:

```bash
python3 operations/phase1-db-lifecycle.py start all --env-file .env
python3 operations/phase1-db-lifecycle.py status --env-file .env
```

With a configured AWS CLI profile, omit `--env-file .env` and use
`--profile YOUR_PROFILE`. Follow the [teammate guide](../teammate-rds-pgadmin-access-guide.md)
for permissions and opening the actual pgAdmin tunnel.

## Monitoring and pausing

- Lambda logs: CloudWatch log group `/aws/lambda/analyticalrx-phase1-dev-schedule`, retained for 14 days.
- Alarms: `analyticalrx-phase1-dev-schedule-failures` and
  `analyticalrx-phase1-dev-schedule-skipped`. These are visible in CloudWatch;
  no email or chat notification subscription is configured.
- To cancel automatic shutdown for a planned late session: open **EventBridge
  Scheduler → Schedule groups → analyticalrx-phase1-dev**, select
  `analyticalrx-phase1-dev-stop`, and disable it. Re-enable it after the work.
  Deploying the template again sets schedules back to enabled.
- The morning readiness check raises a Lambda error if the database, proxy targets,
  or SSM agent is not ready. Investigate the logs and use the lifecycle script.

## Maintaining the deployment

Edit `handler.py`, then regenerate the template from this directory:

```bash
python3 build_template.py
python3 test_handler.py
```

On Windows use `py` instead of `python3`. Deploy `stack.json` using CloudFormation
with `CAPABILITY_IAM` in account `209556026827`, region `us-east-1`. Existing stack
updates must use the same stack name. Do not deploy another copy, which would
create duplicate schedules.

The deploy template includes source inline, dedicated roles, schedules, log
retention, and alarms. Seven tests cover missing metrics, active clients, sessions
appearing during checks, dry-run safety, fixed resource IDs, and repeated starts.
An AWS dry run of `{"action":"stop","dry_run":true}` can check the deployed
execution role and activity logic without issuing stop calls.
