# Development proxy retirement — 2026-11-02

Developer access now follows:

```text
pgAdmin or local backend -> localhost:5433 -> SSM tunnel EC2 -> private RDS:5432
```

The webhook processor retains `processor-lambda-iam-auth-proxy` and IAM authentication.
The development proxy `analytical-rx-phase1-rds-proxy` was deleted after validation.
The private database endpoint is:
`analytical-rx-phase1-dev-db.c6ry4mqo6ydb.us-east-1.rds.amazonaws.com`.

## Developer action

Pull the updated documentation repository, close any old tunnel, then run the
normal [Windows or Linux tunnel command](teammate-rds-pgadmin-access-guide.md).
In an existing pgAdmin server registration, keep `localhost`, port `5433`, database
`analyticalrx`, and SSL mode `Require`. Set the username to
`analyticalrx_data_platform_password_rw` and retrieve its password from
`analytical-rx/phase1/dev/postgres/data-platform-password-rw` in Secrets Manager.
The Windows tunnel script reads that secret and copies the password as before.
The local backend already uses this user and secret; its connection settings do
not change.

The older `analyticalrx_app_rw` user is for the processor's IAM authentication.
Its password does not work for direct developer access. Do not remove its IAM
role membership or change its password to work around a pgAdmin login failure.

## AWS changes

- Added PostgreSQL ingress to DB security group `sg-0baa533faee336e7b` only from
  tunnel security group `sg-063dbd4e747686437`, rule `sgr-0bb4a4aebdc19cdab`.
  No public database access or inbound SSH access was added.
- Developer secret `host` now points at private RDS; its obsolete `proxy_host`
  field was removed. Processor secret `host`/`proxy_host` now point at its retained
  IAM proxy rather than the deleted proxy. Passwords and usernames were preserved.
- Existing developer-group policy already allows the developer password secret;
  IAM policy simulation confirmed access. No new secret-read grant was needed.
- Scheduler and manual lifecycle checks now monitor the retained processor proxy.
  Active SSM sessions still prevent shutdown, covering direct developer connections.
  The weekday/start/stop schedule is unchanged.
- Proxy IAM roles, shared security groups, database users, and secrets were preserved.
  They may be used by retained resources; no cleanup of shared resources was attempted.

## Validation

- AWS inventory: no ECS clusters, App Runner services, or Elastic Beanstalk
  environments in `us-east-1`; the only EC2 is the tunnel. The processor Lambda's
  `DB_HOST` already references its retained proxy. No Lambda references the retired
  endpoint. The retired proxy reported zero clients in all 30 recent minute samples.
- Direct psql connection through SSM succeeded with TLS, correct database/user,
  and read access to the control-plane schema, in a read-only transaction.
- The updated Bash tunnel script was exercised on a temporary local port; direct
  PostgreSQL connection reported `ssl = true`.
- Local Spring Boot backend started on Java 21 with the same developer credential,
  connecting through the direct tunnel. `/actuator/health` returned `UP`.
  System Maven was used initially because the checkout lacked wrapper configuration.
  The missing Maven wrapper properties were restored, and the Windows runner can
  also fall back to installed Maven for incomplete checkouts.
- Deployed scheduler readiness passed. A deployed shutdown dry run refused to
  stop while the direct developer tunnel was active. Seven local safety tests pass.
- Windows PowerShell was not available on the validation machine; its tunnel
  destination/secret changes were reviewed, but not executed on Windows.

No application rows were inserted or changed for these checks. Test backend and
SSM sessions were closed afterward.

## Recovery

The pre-delete proxy configuration, target settings, role ARN, and secret ARNs
(no secret values) are saved in
[retired-development-proxy.json](dev-schedule/retired-development-proxy.json).
If direct development access fails, first check database/tunnel status, the new
security-group rule, the username above, and the active SSM session.

If a proxy must be restored, an administrator can recreate it from the archived
configuration and register `analytical-rx-phase1-dev-db` as its target. Read back
the newly generated endpoint; do not assume an old endpoint will be reused.
Update developer secret metadata and both tunnel scripts to that endpoint,
restore lifecycle/scheduler checks for the added proxy, and redeploy the scheduler
using its existing CloudFormation stack. Verify connections before switching users.
The retained processor proxy should not be modified during that recovery.
