#!/usr/bin/env bash
set -euo pipefail

# Open the Phase 1 dev database tunnel. Keep this terminal open while connected.
ENV_FILE="${1:-.env}"
LOCAL_PORT="${2:-5433}"
EXPECTED_ACCOUNT="209556026827"
REGION="us-east-1"
TARGET="i-0ee64eae7d8505bfc"
PROXY_HOST="analytical-rx-phase1-rds-proxy.proxy-c6ry4mqo6ydb.us-east-1.rds.amazonaws.com"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Cannot find $ENV_FILE. Create it with your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY." >&2
  exit 1
fi

command -v aws >/dev/null || { echo "Install AWS CLI v2 first." >&2; exit 1; }
command -v session-manager-plugin >/dev/null || { echo "Install the AWS Session Manager Plugin first." >&2; exit 1; }

# The .env file should contain only KEY=value lines supplied by the teammate.
set -a
source "$ENV_FILE"
set +a
unset AWS_PROFILE
export AWS_REGION="$REGION"
export AWS_DEFAULT_REGION="$REGION"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$ACCOUNT" != "$EXPECTED_ACCOUNT" ]]; then
  echo "Wrong AWS account: expected $EXPECTED_ACCOUNT, got $ACCOUNT. No tunnel started." >&2
  exit 1
fi

echo "Connected to the AnalyticalRx AWS account. Keep this terminal open. Press Ctrl+C to close the tunnel."
aws ssm start-session \
  --region "$REGION" \
  --target "$TARGET" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$PROXY_HOST\"],\"portNumber\":[\"5432\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}"
