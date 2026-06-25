[CmdletBinding()]
param(
  [string]$Branch = "main",
  [string]$GhConfigDir = "D:\codex\.gh-config",
  [string]$TokenFile = "D:\codex\.secrets\github_token",
  [switch]$SkipPagesSourceUpdate,
  [switch]$SkipPagesBuild
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $RepoRoot

function Invoke-Git {
  & git -c http.sslBackend=openssl @args
  if ($LASTEXITCODE -ne 0) {
    throw "git command failed: $($args -join ' ')"
  }
}

function Invoke-Gh {
  & gh @args
  if ($LASTEXITCODE -ne 0) {
    throw "gh command failed: $($args -join ' ')"
  }
}

if (-not (Test-Path -LiteralPath $GhConfigDir)) {
  New-Item -ItemType Directory -Path $GhConfigDir -Force | Out-Null
}
$env:GH_CONFIG_DIR = $GhConfigDir

if (-not $env:GH_TOKEN -and -not $env:GITHUB_TOKEN -and (Test-Path -LiteralPath $TokenFile)) {
  $token = (Get-Content -LiteralPath $TokenFile -Raw).Trim()
  if ($token) {
    $env:GH_TOKEN = $token
  }
}

$entryFiles = @("app.html", "index.html", "workbench.html")
$hashes = foreach ($file in $entryFiles) {
  if (-not (Test-Path -LiteralPath $file)) {
    throw "Missing required entry file: $file"
  }
  Get-FileHash -Algorithm SHA256 -LiteralPath $file
}
if (($hashes.Hash | Select-Object -Unique).Count -ne 1) {
  throw "app.html, index.html, and workbench.html must stay identical before deploy."
}

$status = & git status --porcelain
if ($LASTEXITCODE -ne 0) {
  throw "git status failed"
}
if ($status) {
  throw "Working tree is not clean. Commit or stash local changes before deploy."
}

$remoteUrl = (& git config --get remote.origin.url).Trim()
if ($remoteUrl -notmatch "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(?:\.git)?$") {
  throw "Could not parse GitHub owner/repo from remote.origin.url: $remoteUrl"
}
$owner = $Matches.owner
$repo = $Matches.repo

$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $authStatus = & gh auth status --hostname github.com 2>&1
  $authExitCode = $LASTEXITCODE
}
finally {
  $ErrorActionPreference = $oldErrorActionPreference
}
if ($authExitCode -ne 0 -and -not $env:GH_TOKEN -and -not $env:GITHUB_TOKEN) {
  throw "GitHub auth missing. Use D:\codex\.secrets\github_token or run gh auth login with GH_CONFIG_DIR=$GhConfigDir."
}

$gitAuthArgs = @()
$tokenForGit = if ($env:GH_TOKEN) { $env:GH_TOKEN } elseif ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } else { $null }
if ($tokenForGit) {
  $basic = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("x-access-token:$tokenForGit"))
  $gitAuthArgs = @(
    "-c", "credential.helper=",
    "-c", "http.https://github.com/.extraheader=AUTHORIZATION: basic $basic"
  )
}
else {
  $gitAuthArgs = @(
    "-c", "credential.https://github.com.helper=!gh auth git-credential"
  )
}

& git -c http.sslBackend=openssl @gitAuthArgs push origin "HEAD:$Branch"
if ($LASTEXITCODE -ne 0) {
  throw "git push failed"
}

if (-not $SkipPagesSourceUpdate) {
  $pagesBody = @{
    source = @{
      branch = $Branch
      path = "/"
    }
  } | ConvertTo-Json -Depth 5 -Compress

  $tmpDir = Join-Path -Path (Split-Path -Parent $RepoRoot) -ChildPath ".tmp"
  if (-not (Test-Path -LiteralPath $tmpDir)) {
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
  }
  $pagesInput = Join-Path -Path $tmpDir -ChildPath "github-pages-source.json"
  [System.IO.File]::WriteAllText($pagesInput, $pagesBody, [System.Text.UTF8Encoding]::new($false))

  try {
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $null = & gh api "repos/$owner/$repo/pages" 2>$null
      $pagesExitCode = $LASTEXITCODE
    }
    finally {
      $ErrorActionPreference = $oldErrorActionPreference
    }

    if ($pagesExitCode -eq 0) {
      Invoke-Gh api --method PUT "repos/$owner/$repo/pages" --input $pagesInput
    }
    else {
      Invoke-Gh api --method POST "repos/$owner/$repo/pages" --input $pagesInput
    }
  }
  finally {
    Remove-Item -LiteralPath $pagesInput -ErrorAction SilentlyContinue
  }
}

if (-not $SkipPagesBuild) {
  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $null = & gh api --method POST "repos/$owner/$repo/pages/builds" 2>$null
    $buildExitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }
  if ($buildExitCode -ne 0) {
    Write-Warning "Pages build trigger failed; GitHub may still build automatically from the push."
  }
}

$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $pagesUrl = (& gh api "repos/$owner/$repo/pages" --jq ".html_url" 2>$null)
}
finally {
  $ErrorActionPreference = $oldErrorActionPreference
}
Write-Host "Deployed commit:"
Invoke-Git log -1 --oneline
if ($pagesUrl) {
  Write-Host "GitHub Pages URL: $pagesUrl"
}
