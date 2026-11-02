#!/usr/bin/env python3
"""Safely manage the AnalyticalRx Phase 1 development DB and SSM tunnel."""

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


ACCOUNT = "209556026827"
REGION = "us-east-1"
DB_ID = "analytical-rx-phase1-dev-db"
TUNNEL_ID = "i-0ee64eae7d8505bfc"
PROXIES = ("processor-lambda-iam-auth-proxy",)
POLL_SECONDS = 15


class LifecycleError(RuntimeError):
    pass


def load_env_file(filename):
    """Load simple KEY=VALUE entries without overriding existing environment."""
    if not filename:
        return
    path = Path(filename)
    if not path.is_file():
        raise LifecycleError(f"Environment file not found: {path}")
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key, value = key.strip(), value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        if key in {"AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN"}:
            os.environ.setdefault(key, value)


def aws(args, profile=None, json_output=True):
    command = ["aws", *args, "--region", REGION]
    if profile:
        command.extend(["--profile", profile])
    if json_output:
        command.extend(["--output", "json"])
    result = subprocess.run(command, text=True, capture_output=True)
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise LifecycleError(f"AWS CLI command failed: {detail}")
    if json_output:
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            raise LifecycleError("AWS CLI returned invalid JSON output.") from exc
    return result.stdout.strip()


def check_identity(profile):
    identity = aws(["sts", "get-caller-identity"], profile)
    if identity.get("Account") != ACCOUNT:
        raise LifecycleError(
            f"Wrong AWS account. Expected {ACCOUNT}; received {identity.get('Account')}."
        )
    arn = identity.get("Arn", "")
    if ":root" in arn:
        raise LifecycleError(
            "This script does not run with AWS root credentials. Configure your own "
            "teammate IAM profile and the Phase 1 lifecycle policy, then retry."
        )
    print(f"AWS account: {ACCOUNT} ({arn})")


def db_status(profile):
    response = aws(["rds", "describe-db-instances", "--db-instance-identifier", DB_ID], profile)
    instances = response.get("DBInstances", [])
    if not instances:
        raise LifecycleError(f"Database not found: {DB_ID}")
    return instances[0].get("DBInstanceStatus", "unknown")


def proxy_details(profile, name):
    response = aws(["rds", "describe-db-proxies", "--db-proxy-name", name], profile)
    proxies = response.get("DBProxies", [])
    if not proxies:
        raise LifecycleError(f"RDS Proxy not found: {name}")
    return proxies[0]


def proxy_target_health(profile, name):
    response = aws([
        "rds", "describe-db-proxy-targets", "--db-proxy-name", name
    ], profile)
    targets = response.get("Targets", [])
    if not targets:
        return "no targets"
    return ", ".join(
        f"{target.get('Target', {}).get('RdsResourceId', 'target')}: "
        f"{target.get('TargetHealth', {}).get('State', 'unknown')}"
        for target in targets
    )


def tunnel_status(profile):
    response = aws(["ec2", "describe-instances", "--instance-ids", TUNNEL_ID], profile)
    reservations = response.get("Reservations", [])
    if not reservations or not reservations[0].get("Instances"):
        raise LifecycleError(f"Tunnel instance not found: {TUNNEL_ID}")
    return reservations[0]["Instances"][0].get("State", {}).get("Name", "unknown")


def active_sessions(profile):
    response = aws([
        "ssm", "describe-sessions", "--state", "Active",
        "--filters", f"key=Target,value={TUNNEL_ID}",
    ], profile)
    return response.get("Sessions", [])


def check_no_database_use(profile):
    now = dt.datetime.now(dt.timezone.utc)
    end = (now - dt.timedelta(minutes=2)).replace(second=0, microsecond=0)
    start = end - dt.timedelta(minutes=15)
    if active_sessions(profile):
        raise LifecycleError("Database stop cancelled: an SSM tunnel session is active.")
    print("Checking completed processor proxy client metrics and developer SSM sessions...")
    for proxy in PROXIES:
        response = aws([
            "cloudwatch", "get-metric-statistics", "--namespace", "AWS/RDS",
            "--metric-name", "ClientConnections", "--dimensions", f"Name=ProxyName,Value={proxy}",
            "--start-time", start.isoformat(), "--end-time", end.isoformat(),
            "--period", "60", "--statistics", "Maximum",
        ], profile)
        points = response.get("Datapoints", [])
        expected = {start + dt.timedelta(minutes=i) for i in range(15)}
        stamps = {dt.datetime.fromisoformat(p["Timestamp"].replace("Z", "+00:00")) for p in points}
        if not expected.issubset(stamps):
            raise LifecycleError("Database stop cancelled: incomplete recent proxy client metrics.")
        if any(p["Maximum"] > 0 for p in points):
            raise LifecycleError("Database stop cancelled: recent processor proxy clients detected.")
    if active_sessions(profile):
        raise LifecycleError("Database stop cancelled: an SSM tunnel session started during checks.")


def confirm_stop(resource_label, exact_phrase, impact):
    print(f"\nYou are about to stop {resource_label}.")
    print(impact)
    if not sys.stdin.isatty():
        raise LifecycleError("Stop cancelled: interactive confirmation is required.")
    typed = input(f'Type "{exact_phrase}" to continue: ').strip()
    if typed != exact_phrase:
        raise LifecycleError("Stop cancelled; confirmation did not match.")


def wait_until(label, check, accepted, timeout):
    deadline = time.monotonic() + timeout
    while True:
        state = check()
        print(f"{label}: {state}")
        if accepted(state):
            return state
        if time.monotonic() >= deadline:
            raise LifecycleError(f"Timed out waiting for {label}; last state: {state}")
        time.sleep(POLL_SECONDS)


def start_database(profile, timeout):
    state = db_status(profile)
    if state == "stopped":
        aws(["rds", "start-db-instance", "--db-instance-identifier", DB_ID], profile)
    elif state not in ("available", "starting"):
        raise LifecycleError(f"Database cannot be started from state {state}.")
    wait_until("Database", lambda: db_status(profile), lambda value: value == "available", timeout)
    for proxy in PROXIES:
        wait_until(
            f"{proxy} target health",
            lambda proxy=proxy: proxy_target_health(profile, proxy),
            lambda value: value != "no targets" and all(
                part.rsplit(": ", 1)[-1] == "AVAILABLE" for part in value.split(", ")
            ),
            timeout,
        )
    print("Database and the processor RDS Proxy target are ready.")


def start_tunnel(profile, timeout):
    state = tunnel_status(profile)
    if state == "stopped":
        aws(["ec2", "start-instances", "--instance-ids", TUNNEL_ID], profile)
    elif state not in ("running", "pending"):
        raise LifecycleError(f"Tunnel instance cannot be started from state {state}.")
    wait_until("Tunnel instance", lambda: tunnel_status(profile), lambda value: value == "running", timeout)

    def ssm_status():
        response = aws(["ssm", "describe-instance-information", "--filters",
                        f"Key=InstanceIds,Values={TUNNEL_ID}"], profile)
        items = response.get("InstanceInformationList", [])
        return items[0].get("PingStatus", "not registered") if items else "not registered"

    wait_until("SSM agent", ssm_status, lambda value: value == "Online", timeout)
    print("Tunnel host is online. Start the port-forwarding command when you need it.")


def stop_database(profile, timeout):
    state = db_status(profile)
    if state == "stopped":
        print("Database is already stopped.")
        return
    if state != "available":
        raise LifecycleError(f"Database cannot be safely stopped from state {state}.")
    check_no_database_use(profile)
    confirm_stop(
        "the shared Phase 1 development database", "STOP SHARED DEV DATABASE",
        "Database-backed API, Lambda, and developer work will be unavailable until "
        "it is started again. The activity check is a recent snapshot and cannot "
        "prevent a new request from arriving after the check.",
    )
    # Recheck immediately after confirmation so a long pause cannot bypass the gate.
    check_no_database_use(profile)
    aws(["rds", "stop-db-instance", "--db-instance-identifier", DB_ID], profile)
    wait_until("Database", lambda: db_status(profile), lambda value: value == "stopped", timeout)
    print("Database is stopped. RDS Proxy resources remain provisioned and continue to incur charges.")


def stop_tunnel(profile, timeout):
    state = tunnel_status(profile)
    if state == "stopped":
        print("Tunnel instance is already stopped.")
        return
    if state != "running":
        raise LifecycleError(f"Tunnel instance cannot be safely stopped from state {state}.")
    sessions = active_sessions(profile)
    if sessions:
        raise LifecycleError(
            f"Tunnel stop cancelled: {len(sessions)} active SSM session(s) are connected."
        )
    print("Stopping the tunnel closes new local database access for everyone using it.")
    confirm_stop(
        "the shared SSM database tunnel host", "STOP SHARED DB TUNNEL",
        "This closes new local database access through the shared tunnel host.",
    )
    sessions = active_sessions(profile)
    if sessions:
        raise LifecycleError("Tunnel stop cancelled: an SSM session started during confirmation.")
    aws(["ec2", "stop-instances", "--instance-ids", TUNNEL_ID], profile)
    wait_until("Tunnel instance", lambda: tunnel_status(profile), lambda value: value == "stopped", timeout)


def show_status(profile):
    print(f"Database {DB_ID}: {db_status(profile)}")
    print(f"Tunnel {TUNNEL_ID}: {tunnel_status(profile)}")
    sessions = active_sessions(profile)
    print(f"Active SSM tunnel sessions: {len(sessions)}")
    for name in PROXIES:
        details = proxy_details(profile, name)
        print(f"RDS Proxy {name}: {details.get('Status', 'unknown')}; "
              f"IAM auth={details.get('IAMAuth', 'unknown')}; "
              f"target health={proxy_target_health(profile, name)}")
    print("RDS Proxies have no stop operation. This script never deletes them.")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Start or stop only the AnalyticalRx Phase 1 dev database and tunnel."
    )
    parser.add_argument("--profile", help="AWS CLI profile to use")
    parser.add_argument("--env-file", help="Load AWS credentials from a local .env file")
    parser.add_argument("--timeout", type=int, default=1800,
                        help="Seconds to wait for AWS resources (default: 1800)")
    subparsers = parser.add_subparsers(dest="action", required=True)
    status = subparsers.add_parser("status", help="Show database, tunnel, proxy, and session status")
    status.add_argument("--profile", default=argparse.SUPPRESS)
    status.add_argument("--env-file", default=argparse.SUPPRESS)
    status.add_argument("--timeout", type=int, default=argparse.SUPPRESS)
    for action in ("start", "stop"):
        sub = subparsers.add_parser(action)
        sub.add_argument("resource", choices=("database", "tunnel", "all") if action == "start" else ("database", "tunnel"))
        sub.add_argument("--profile", default=argparse.SUPPRESS)
        sub.add_argument("--env-file", default=argparse.SUPPRESS)
        sub.add_argument("--timeout", type=int, default=argparse.SUPPRESS)
    return parser.parse_args()


def main():
    args = parse_args()
    if args.timeout <= 0:
        raise LifecycleError("--timeout must be greater than zero.")
    load_env_file(args.env_file)
    if not shutil.which("aws"):
        raise LifecycleError("AWS CLI was not found. Install AWS CLI v2 and retry.")
    os.environ["AWS_DEFAULT_REGION"] = REGION
    check_identity(args.profile)
    if args.action == "status":
        show_status(args.profile)
    elif args.action == "start":
        if args.resource in ("database", "all"):
            start_database(args.profile, args.timeout)
        if args.resource in ("tunnel", "all"):
            start_tunnel(args.profile, args.timeout)
    elif args.action == "stop":
        if args.resource == "database":
            stop_database(args.profile, args.timeout)
        else:
            stop_tunnel(args.profile, args.timeout)


if __name__ == "__main__":
    try:
        main()
    except (LifecycleError, KeyboardInterrupt) as exc:
        if isinstance(exc, KeyboardInterrupt):
            print("Cancelled.", file=sys.stderr)
            sys.exit(130)
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
