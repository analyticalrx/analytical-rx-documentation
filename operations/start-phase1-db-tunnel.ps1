param(
  [string]$EnvFile = ".env",
  [int]$LocalPort = 5433,
  [bool]$CopyPasswordToClipboard = $true,
  [switch]$ShowPassword
)

$ErrorActionPreference = "Stop"

$ExpectedAccount = "209556026827"
$Region = "us-east-1"
$SecretId = "analytical-rx/phase1/dev/postgres/app-rw"
$TunnelInstanceId = "i-0ee64eae7d8505bfc"
$ProxyHost = "analytical-rx-phase1-rds-proxy.proxy-c6ry4mqo6ydb.us-east-1.rds.amazonaws.com"

function Require-Command {
  param([string]$Name, [string]$InstallHint)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name is not installed or not available in PATH. $InstallHint"
  }
}

function Import-DotEnv {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    throw "Could not find .env file at: $Path"
  }

  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) {
      return
    }

    $separatorIndex = $line.IndexOf("=")
    $name = $line.Substring(0, $separatorIndex).Trim()
    $value = $line.Substring($separatorIndex + 1).Trim()

    if (
      ($value.StartsWith('"') -and $value.EndsWith('"')) -or
      ($value.StartsWith("'") -and $value.EndsWith("'"))
    ) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    [Environment]::SetEnvironmentVariable($name, $value, "Process")
  }
}

Require-Command "aws" "Install AWS CLI v2 from AWS."
Require-Command "session-manager-plugin" "Install AWS Session Manager Plugin for Windows."

if ($env:AWS_PROFILE) {
  Write-Host "Ignoring AWS_PROFILE=$($env:AWS_PROFILE) for this tunnel session."
  Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
}

Import-DotEnv -Path $EnvFile

if ($env:AWS_ACCESS_KEY -and -not $env:AWS_ACCESS_KEY_ID) {
  $env:AWS_ACCESS_KEY_ID = $env:AWS_ACCESS_KEY
}

if (-not $env:AWS_ACCESS_KEY_ID) {
  throw "Missing AWS_ACCESS_KEY or AWS_ACCESS_KEY_ID in $EnvFile"
}

if (-not $env:AWS_SECRET_ACCESS_KEY) {
  throw "Missing AWS_SECRET_ACCESS_KEY in $EnvFile"
}

$env:AWS_REGION = $Region
$env:AWS_DEFAULT_REGION = $Region

Write-Host "Checking AWS account..."
$identity = aws sts get-caller-identity --output json | ConvertFrom-Json

if ($identity.Account -ne $ExpectedAccount) {
  throw "Wrong AWS account. Expected $ExpectedAccount but got $($identity.Account) for $($identity.Arn)."
}

Write-Host "AWS identity OK: $($identity.Arn)"
Write-Host "Fetching database connection secret..."

$secretString = aws secretsmanager get-secret-value `
  --secret-id $SecretId `
  --query SecretString `
  --output text

$secret = $secretString | ConvertFrom-Json

Write-Host ""
Write-Host "pgAdmin settings"
Write-Host "---------------"
Write-Host "Name                 : AnalyticalRx Phase 1 Dev"
Write-Host "Host                 : localhost"
Write-Host "Port                 : $LocalPort"
Write-Host "Maintenance database : $($secret.dbname)"
Write-Host "Username             : $($secret.username)"
Write-Host "SSL mode             : Require"

if ($CopyPasswordToClipboard) {
  try {
    Set-Clipboard -Value $secret.password
    Write-Host "Password             : copied to clipboard"
  } catch {
    Write-Warning "Could not copy password to clipboard. Run with -ShowPassword to print it temporarily."
  }
} elseif ($ShowPassword) {
  Write-Host "Password             : $($secret.password)"
} else {
  Write-Host "Password             : fetched from Secrets Manager; rerun with -ShowPassword if needed"
}

Write-Host ""
Write-Host "Starting SSM tunnel. Keep this window open while using pgAdmin or psql."
Write-Host "Press Ctrl+C to close the tunnel."
Write-Host ""

$parameters = @{
  host = @($ProxyHost)
  portNumber = @("5432")
  localPortNumber = @("$LocalPort")
} | ConvertTo-Json -Compress

aws ssm start-session `
  --target $TunnelInstanceId `
  --document-name AWS-StartPortForwardingSessionToRemoteHost `
  --parameters $parameters
