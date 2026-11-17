# Processor Lambda direct RDS evaluation

Evaluated: 2026-11-17. Decision: feasible candidate for development; retain the
proxy until the readiness checks below pass. This evaluation did not change AWS
resources, invoke the processing handler, or send test messages.

## Expected saving

The retained proxy cost $5.0399 for November 9–15, excluding tax. Removing it
would save approximately $21.60 per 30 days at that rate. The recent overall
$47.16 monthly run rate would become approximately $25.56 before tax if other
usage stays comparable. These are extrapolations, not billing forecasts.

## Findings from the live account and deployed code

| Check | Result |
| --- | --- |
| RDS IAM authentication | Enabled on `analytical-rx-phase1-dev-db` |
| Processor identity | `analyticalrx_app_rw`, `USE_IAM_AUTH=true` |
| Direct database permission | IAM policy simulation returned `allowed` for the processor role on the exact DB resource/user ARN |
| Network location | Processor and database are in `vpc-009878654ad2bac42` |
| Direct network access | Missing: DB SG `sg-0baa533faee336e7b` does not allow PostgreSQL from processor SG `sg-05d7ea352dbbb1de8` |
| SQS concurrency | Existing event-source mapping already caps concurrent invocations at 2; batch size is 10 |
| Lambda concurrency quota | Account limit 10, unreserved 10, no processor reserved concurrency configured |
| Connection pool | Maximum 3 per execution environment by default, minimum idle 1 |
| Authentication refresh | Deployed Hikari pool calls `getPassword()` when opening connections; deployed provider generates IAM tokens dynamically |
| TLS | IAM connection URL includes `sslmode=require`; certificate/hostname verification should be included in the direct-connection probe |
| RDS resource use, Nov 3–17 | Hourly minimum FreeableMemory samples ranged from 91.2 to 128.4 MiB; hourly peak SwapUsage reached 222.6 MiB; peak reported DB connections 5 |
| Workload evidence | No processor invocation/concurrency datapoints returned for the requested period; throughput and peak behavior remain unvalidated |
| Queue retry settings | Visibility timeout 30 seconds, Lambda timeout 120 seconds, DLQ `maxReceiveCount=3` |
| Partial batch responses | `ReportBatchItemFailures` is enabled |

The deployment package was downloaded for static inspection and its SHA-256 was
verified against Lambda's `CodeSha256`:
`j2vQSno5TkF1JXG61f9kWZyUppT0yR1QO/6X/ch0J8Q=`.
The live code was last modified September 4, 2026. Local uncommitted processor
edits were preserved and were not treated as the deployed implementation.

The IAM policy simulation is not an authentication test. Direct IAM login from
an execution environment using the processor role remains untested. No new
security-group rule was added during this evaluation.

## Readiness work before switching

1. **Correct retry timing.** A 30-second visibility timeout can expire before a
   120-second invocation finishes. AWS recommends at least six times the Lambda
   timeout: 720 seconds here, plus any batching window. Review increasing the
   DLQ receive count from 3 to at least 5. These are existing pipeline concerns,
   independent of the proxy change.
2. **Bound connections and inspect memory.** Keep the existing SQS concurrency
   cap at 2. Start the direct-connection trial with `DB_MAX_POOL=1` and evaluate
   minimum idle 0. Two active execution environments could then each use one
   connection. This is not a hard ceiling on all physical connections: warm/frozen
   environments, manual invokes, and local developer pools also consume them.
   Check live `max_connections`, connection reservations, available memory, and
   swap trends before a sustained test. Low free memory and allocated swap warrant
   investigation; they do not by themselves prove an active OOM incident. IAM
   authentication is already enabled, so do not assume all IAM memory overhead
   would be newly introduced by this migration.
3. **Add narrowly scoped private access for the trial.** Permit TCP 5432 from
   the processor security group to the DB security group. Keep RDS private and
   retain the proxy during testing. Verify TLS and IAM login using the actual
   processor role and database endpoint.
4. **Replace proxy-dependent operating checks.** Both lifecycle tools currently
   inspect proxy clients/target health. Once direct connections exist, proxy
   metrics alone cannot establish processor idleness. Define direct DB activity
   checks and a way to drain/pause queue processing before overnight shutdown;
   resume processing only after database readiness. Keep shutdown conservative
   when activity cannot be determined. Do not simply remove the proxy checks.
5. **Verify downstream retries.** The deployed handler publishes to the processed
   queue before saving the archive. The DB insert uses `ON CONFLICT(message_id)
   DO NOTHING`, but that does not make the prior SQS publish idempotent. A DB
   failure and retry can publish a duplicate downstream event. Validate the
   downstream consumer's deduplication behavior before a connection-path change.

## Validation and cutover sequence

- Keep the existing processor, endpoint, and proxy in place during isolated testing.
- Verify read-only TLS/IAM access as the processor execution role, plus schema and
  INSERT permissions, without sending real webhook data.
- Exercise synthetic messages in an isolated test queue/table or equivalent
  environment. Check successful persistence and downstream delivery, duplicate
  replay, transient DB failure, partial-batch failures, and DLQ behavior.
- Exercise both cold and warm connections, reconnect after more than 15 minutes,
  recovery after a DB restart, and a two-invocation burst with an active developer
  backend. Observe database memory, swap trends, connection count and queue age.
- Test the revised overnight drain/startup behavior with direct connections.
- Only after passing: change the live `DB_HOST` and relevant secret endpoint
  metadata to the DB endpoint while preserving IAM auth. Observe processing with
  the proxy still provisioned for rollback. Then delete the proxy.
- Rollback before deletion: restore the proxy hostname and prior pool settings;
  preserve the SQS endpoint. Do not introduce public database access.

No synthetic end-to-end or direct IAM connection test was run in this evaluation.
The network prerequisite is absent and the retry/memory findings need resolving
before treating a trial as a safe live cutover. Developer pgAdmin/backend access
already uses its own direct SSM path and need not change.

## Sources

- [AWS Lambda and RDS connections](https://docs.aws.amazon.com/lambda/latest/dg/services-rds.html)
- [SQS visibility timeout and retry guidance](https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-configure.html)
- [SQS maximum concurrency](https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-scaling.html)
- [RDS IAM authentication and memory considerations](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html)
