[CmdletBinding()]
param(
  [string]$TokenFile = "D:\codex\.secrets\github_token",
  [string]$Scopes = "repo workflow read:org gist"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$node = Get-Command node -ErrorAction Stop

$env:COCO_GITHUB_TOKEN_FILE = $TokenFile
$env:COCO_GITHUB_SCOPES = $Scopes

$js = @'
const fs = require('fs');
const path = require('path');
const https = require('https');

const clientId = '0120e057bd645470c1ed';
const tokenFile = process.env.COCO_GITHUB_TOKEN_FILE;
const scopes = process.env.COCO_GITHUB_SCOPES || 'repo workflow read:org gist';

function requestJson(options, bodyObj) {
  const body = bodyObj ? new URLSearchParams(bodyObj).toString() : '';
  return new Promise((resolve, reject) => {
    const req = https.request({
      ...options,
      timeout: 30000,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'codex-coco-deploy',
        ...(body ? {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(body)
        } : {}),
        ...(options.headers || {})
      }
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (error) {
          reject(new Error(data || error.message));
        }
      });
    });
    req.on('timeout', () => req.destroy(new Error('request timed out')));
    req.on('error', reject);
    req.end(body);
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function pollToken(device) {
  let interval = Math.max(5, Number(device.interval || 5));
  const deadline = Date.now() + Number(device.expires_in || 900) * 1000;

  while (Date.now() < deadline) {
    let result;
    try {
      result = await requestJson({
        method: 'POST',
        hostname: 'github.com',
        path: '/login/oauth/access_token'
      }, {
        client_id: clientId,
        device_code: device.device_code,
        grant_type: 'urn:ietf:params:oauth:grant-type:device_code'
      });
    } catch (error) {
      await sleep(interval * 1000);
      continue;
    }

    if (result.access_token) {
      return result.access_token;
    }
    if (result.error === 'authorization_pending') {
      await sleep(interval * 1000);
      continue;
    }
    if (result.error === 'slow_down') {
      interval += 5;
      await sleep(interval * 1000);
      continue;
    }
    throw new Error(result.error_description || result.error || 'authorization failed');
  }

  throw new Error('authorization timed out');
}

async function main() {
  const device = await requestJson({
    method: 'POST',
    hostname: 'github.com',
    path: '/login/device/code'
  }, {
    client_id: clientId,
    scope: scopes
  });

  console.log(`Open: ${device.verification_uri}`);
  console.log(`Code: ${device.user_code}`);
  console.log(`Expires in: ${Math.floor(Number(device.expires_in || 900) / 60)} minutes`);
  console.log('Waiting for GitHub authorization...');

  const token = await pollToken(device);
  const user = await requestJson({
    method: 'GET',
    hostname: 'api.github.com',
    path: '/user',
    headers: {
      'Accept': 'application/vnd.github+json',
      'Authorization': `Bearer ${token}`
    }
  });

  fs.mkdirSync(path.dirname(tokenFile), { recursive: true });
  fs.writeFileSync(tokenFile, `${token}\n`, { mode: 0o600 });
  console.log(`Authorized GitHub account: ${user.login || 'github-user'}`);
  console.log(`Token saved to: ${tokenFile}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
'@

& $node.Source -e $js
if ($LASTEXITCODE -ne 0) {
  throw "GitHub token setup failed"
}
