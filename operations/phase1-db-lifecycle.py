#!/usr/bin/env python3
"""Start, stop, or inspect the AnalyticalRx Phase 1 dev RDS instance."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path


EXPECTED_ACCOUNT = "209556026827"
REGION = "us-east-1"
DB_INSTANCE_ID = "analytical-rx-phase1-dev-db"
POLL_SECONDS = 15
DEFAULT_TIMEOUT_MINUTES = 45


class CommandError(RuntimeError):
    pass


def load_env_file(path: str | None) -> None:
    """Load simple KEY=value entries without replacing existing environment values."""
    if not path:
        return

    env_path = Path(path).expanduser()
    if not env_path.is_file():
        raise CommandError(f"Environment file not found: {env_path}")

    for line_number, raw_line in enumerate(env_path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        name, value = line.split("=", 1)
        name = name.strip()
        value = value.strip()
        if not name:
            raise CommandError(f"Invalid entry on line {line_number} of {env_path}")

        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]

        if name == "AWS_ACCESS_KEY" and "AWS_ACCESS_KEY_ID" not in os.environ:
            os.environ["AWS_ACCESS_KEY_ID"] = value
        elif name not in os.environ:
            os.environ[name] = value


def run_aws(args: list[str], *, parse_json: bool = False):
    command = ["aws", *args, "--no-cli-pager"]
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
    except FileNotFoundError as exc:
        raise CommandError("AWS CLI was not found. Install AWS CLI v2 and try again.") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout).strip()
        raise CommandError(detail or f"AWS CLI command failed: {shlex.join(command)}") from exc

    return json.loads(result.stdout) if parse_json else result.stdout.strip()


def aws_profile_args(profile: str | None) -> list[str]:
    return ["--profile", profile] if profile else []


def check_account(profile: str | None) -> None:
    identity = run_aws(["sts", "get-caller-identity", *aws_profile_args(profile)], parse_json=True)
    if identity.get("Account") != EXPECTED_ACCOUNT:
        raise CommandError(
            f"Wrong AWS account. Expected {EXPECTED_ACCOUNT}; current account is "
            f"{identity.get('Account', 'unknown')}. No database action was taken."
        )
    print("AWS account verified.")


def describe_database(profile: str | None) -> dict:
    response = run_aws(
        [
            "rds",
            "describe-db-instances",
            "--region",
            REGION,
            "--db-instance-identifier",
            DB_INSTANCE_ID,
            *aws_profile_args(profile),
        ],
        parse_json=True,
    )
    instances = response.get("DBInstances", [])
    if len(instances) != 1:
        raise CommandError(f"Could not find exactly one database named {DB_INSTANCE_ID}.")
    return instances[0]


def show_status(instance: dict) -> str:
    status = instance["DBInstanceStatus"]
    print(f"Database: {DB_INSTANCE_ID}")
    print(f"Region:   {REGION}")
    print(f"Status:   {status}")
    print(f"Class:    {instance.get('DBInstanceClass', 'unknown')}")
    return status


def wait_for_status(profile: str | None, target_status: str, timeout_minutes: int) -> dict:
    deadline = time.monotonic() + timeout_minutes * 60
    while True:
        instance = describe_database(profile)
        status = instance["DBInstanceStatus"]
        print(f"Current status: {status}")
        if status == target_status:
            return instance
        if status in {"failed", "inaccessible-encryption-credentials", "incompatible-restore"}:
            raise CommandError(f"Database entered unexpected status '{status}'. Check the RDS console.")
        if time.monotonic() >= deadline:
            raise CommandError(
                f"Timed out waiting for status '{target_status}'. Current status is '{status}'."
            )
        time.sleep(POLL_SECONDS)


def confirm_stop(skip_confirmation: bool) -> None:
    if skip_confirmation:
        return
    try:
        answer = input(f"Type '{DB_INSTANCE_ID}' to stop this shared dev database: ").strip()
    except EOFError as exc:
        raise CommandError("Stop cancelled. Use --yes only when running this intentionally.") from exc
    if answer != DB_INSTANCE_ID:
        raise CommandError("Stop cancelled; database was not changed.")


def start_database(profile: str | None, timeout_minutes: int) -> None:
    instance = describe_database(profile)
    status = show_status(instance)
    if status == "available":
        print("Database is already available.")
        return
    if status == "stopped":
        print("Requesting database start...")
        run_aws(
            [
                "rds",
                "start-db-instance",
                "--region",
                REGION,
                "--db-instance-identifier",
                DB_INSTANCE_ID,
                *aws_profile_args(profile),
            ]
        )
    elif status == "stopping":
        print("Waiting for the current stop operation to finish before starting...")
        wait_for_status(profile, "stopped", timeout_minutes)
        run_aws(
            [
                "rds",
                "start-db-instance",
                "--region",
                REGION,
                "--db-instance-identifier",
                DB_INSTANCE_ID,
                *aws_profile_args(profile),
            ]
        )
    elif status != "starting":
        raise CommandError(f"Cannot start the database while it is in status '{status}'.")

    print("Waiting for the database to become available...")
    show_status(wait_for_status(profile, "available", timeout_minutes))
    print("Database is ready.")


def stop_database(profile: str | None, timeout_minutes: int, skip_confirmation: bool) -> None:
    instance = describe_database(profile)
    status = show_status(instance)
    if status == "stopped":
        print("Database is already stopped.")
        return
    if status == "stopping":
        print("Waiting for the current stop operation to finish...")
        show_status(wait_for_status(profile, "stopped", timeout_minutes))
        print("Database is stopped.")
        return
    if status == "starting":
        print("Waiting for the current start operation to finish before stopping...")
        wait_for_status(profile, "available", timeout_minutes)
    elif status != "available":
        raise CommandError(f"Cannot stop the database while it is in status '{status}'.")

    confirm_stop(skip_confirmation)
    print("Requesting database stop...")
    run_aws(
        [
            "rds",
            "stop-db-instance",
            "--region",
            REGION,
            "--db-instance-identifier",
            DB_INSTANCE_ID,
            *aws_profile_args(profile),
        ]
    )
    print("Waiting for the database to stop...")
    show_status(wait_for_status(profile, "stopped", timeout_minutes))
    print("Database is stopped. RDS storage, backups, and the separate RDS proxies can still incur charges.")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=f"Manage the {DB_INSTANCE_ID} RDS instance in {REGION}."
    )
    parser.add_argument("action", choices=("start", "stop", "status"))
    parser.add_argument("--profile", help="AWS CLI profile to use; defaults to the normal AWS CLI credential chain.")
    parser.add_argument("--env-file", help="Optional .env file containing AWS CLI credential variables.")
    parser.add_argument(
        "--timeout-minutes",
        type=int,
        default=DEFAULT_TIMEOUT_MINUTES,
        help=f"Maximum wait for RDS to reach its target state (default: {DEFAULT_TIMEOUT_MINUTES}).",
    )
    parser.add_argument("--yes", action="store_true", help="Skip the confirmation prompt for stop.")
    args = parser.parse_args()

    if args.timeout_minutes < 1:
        parser.error("--timeout-minutes must be at least 1")

    try:
        load_env_file(args.env_file)
        check_account(args.profile)
        if args.action == "status":
            show_status(describe_database(args.profile))
        elif args.action == "start":
            start_database(args.profile, args.timeout_minutes)
        else:
            stop_database(args.profile, args.timeout_minutes, args.yes)
    except (CommandError, json.JSONDecodeError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nInterrupted. Check RDS status before retrying.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
