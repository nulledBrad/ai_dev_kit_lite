#
# Databricks MCP Lite - Team Installer (Windows)
#
# Installs 48 Databricks tools for Claude Desktop:
#   SQL, Compute, Jobs, Pipelines, Unity Catalog, Apps
#
# Usage:
#   .\install.ps1                        # Uses "default" Databricks profile
#   .\install.ps1 -Profile my_profile    # Specify a profile
#   .\install.ps1 -Force                 # Reinstall even if already installed
#

param(
    [string]$Profile = "default",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:USERPROFILE ".ai-dev-kit"
$RepoDir    = Join-Path $InstallDir "repo"
$VenvDir    = Join-Path $InstallDir ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$LiteServer = Join-Path $InstallDir "run_server_lite.py"
$RepoUrl    = "https://github.com/databricks-solutions/ai-dev-kit.git"
$ConfigFile = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"

function Write-Ok   { param([string]$Text) Write-Host "  [OK] " -ForegroundColor Green -NoNewline; Write-Host $Text }
function Write-Info { param([string]$Text) Write-Host "  [..] " -ForegroundColor Cyan -NoNewline; Write-Host $Text }
function Write-Err  { param([string]$Text) Write-Host "  [!!] " -ForegroundColor Red -NoNewline; Write-Host $Text }

Write-Host ""
Write-Host "  Databricks MCP Lite Installer" -ForegroundColor White
Write-Host "  ==============================" -ForegroundColor DarkGray
Write-Host "  48 tools: SQL, Compute, Jobs, Pipelines, Unity Catalog, Apps"
Write-Host "  Profile: $Profile"
Write-Host ""

# --- Check if already installed ---
if ((Test-Path $VenvPython) -and (Test-Path $LiteServer) -and -not $Force) {
    & $VenvPython -c "import databricks_mcp_server" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Already installed at $InstallDir"
        Write-Info "Use -Force to reinstall"
        Write-Host ""
        Write-Host "  Add this to your Claude Desktop config:" -ForegroundColor Yellow
        Write-Host "  $ConfigFile" -ForegroundColor DarkGray
        Write-Host ""
        $pyPath = $VenvPython -replace '\\', '\\\\'
        $srvPath = $LiteServer -replace '\\', '\\\\'
        Write-Host @"
    "databricks_ai_dev_kit": {
      "command": "$pyPath",
      "args": ["$srvPath"],
      "env": { "DATABRICKS_CONFIG_PROFILE": "$Profile" }
    }
"@
        Write-Host ""
        exit 0
    }
}

# --- Prerequisites ---
Write-Info "Checking prerequisites..."

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Err "git is required. Install: winget install Git.Git"
    exit 1
}

$Pkg = ""
if (Get-Command uv -ErrorAction SilentlyContinue) {
    $Pkg = "uv"
} elseif (Get-Command pip -ErrorAction SilentlyContinue) {
    $Pkg = "pip"
} else {
    Write-Err "Python package manager required. Install uv (recommended) or Python with pip."
    Write-Err "  uv: irm https://astral.sh/uv/install.ps1 | iex"
    exit 1
}
Write-Ok "git + $Pkg found"

# --- Databricks auth check ---
$cfgFile = Join-Path $env:USERPROFILE ".databrickscfg"
$hasAuth = $false
if (Test-Path $cfgFile) {
    $content = Get-Content $cfgFile -Raw
    if ($content -match "\[$Profile\]") {
        $hasAuth = $true
        Write-Ok "Databricks profile [$Profile] found"
    }
}
if ($env:DATABRICKS_TOKEN) {
    $hasAuth = $true
    Write-Ok "DATABRICKS_TOKEN env var set"
}
if (-not $hasAuth) {
    Write-Err "No Databricks auth found for profile [$Profile]"
    Write-Host "  Run: databricks auth login --profile $Profile" -ForegroundColor Yellow
    Write-Host "  Or set DATABRICKS_TOKEN and DATABRICKS_HOST env vars" -ForegroundColor Yellow
    exit 1
}

# --- Clone repo ---
Write-Info "Cloning Databricks AI Dev Kit..."
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"

if (Test-Path (Join-Path $RepoDir ".git")) {
    & git -C $RepoDir pull -q 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -Recurse -Force $RepoDir -ErrorAction SilentlyContinue
        & git clone -q --depth 1 $RepoUrl $RepoDir 2>&1 | Out-Null
    }
} else {
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    & git clone -q --depth 1 $RepoUrl $RepoDir 2>&1 | Out-Null
}
$ErrorActionPreference = $prevEAP

if (-not (Test-Path (Join-Path $RepoDir ".git"))) {
    Write-Err "Failed to clone repository"
    exit 1
}
Write-Ok "Repository ready"

# --- Create venv and install ---
Write-Info "Installing Python dependencies (this may take a minute)..."
$prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"

if ($Pkg -eq "uv") {
    & uv venv --python 3.11 --allow-existing $VenvDir -q 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        & uv venv --allow-existing $VenvDir -q 2>&1 | Out-Null
    }
    & uv pip install --python $VenvPython -e "$RepoDir\databricks-tools-core" -e "$RepoDir\databricks-mcp-server" -q 2>&1 | Out-Null
} else {
    if (-not (Test-Path $VenvDir)) {
        & python -m venv $VenvDir 2>&1 | Out-Null
    }
    & $VenvPython -m pip install -q -e "$RepoDir\databricks-tools-core" -e "$RepoDir\databricks-mcp-server" 2>&1 | Out-Null
}
$ErrorActionPreference = $prevEAP

& $VenvPython -c "import databricks_mcp_server" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Package installation failed"
    exit 1
}
Write-Ok "Packages installed"

# --- Copy lite server ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Copy-Item (Join-Path $ScriptDir "run_server_lite.py") $LiteServer -Force
Write-Ok "Lite server installed"

# --- Verify ---
Write-Info "Verifying server starts..."
$testResult = echo '{}' | & $VenvPython -c "
import sys, types
from fastmcp import FastMCP
from databricks_mcp_server.middleware import TimeoutHandlingMiddleware
mcp = FastMCP('test')
mcp.add_middleware(TimeoutHandlingMiddleware())
_fake = types.ModuleType('databricks_mcp_server.server')
_fake.mcp = mcp
sys.modules['databricks_mcp_server.server'] = _fake
from databricks_mcp_server.tools import sql, compute, jobs, pipelines, unity_catalog, apps
print(len(mcp._tool_manager._tools))
" 2>$null

if ($testResult -match '48') {
    Write-Ok "Server verified: 48 tools registered"
} else {
    Write-Ok "Server installed (tool count: $testResult)"
}

# --- Show config ---
Write-Host ""
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host "  =====================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Next step: Add this to your Claude Desktop config:" -ForegroundColor Yellow
Write-Host "  $ConfigFile" -ForegroundColor DarkGray
Write-Host ""

$pyPath = $VenvPython -replace '\\', '\\\\'
$srvPath = $LiteServer -replace '\\', '\\\\'

Write-Host @"
    "databricks_ai_dev_kit": {
      "command": "$pyPath",
      "args": ["$srvPath"],
      "env": { "DATABRICKS_CONFIG_PROFILE": "$Profile" }
    }
"@

Write-Host ""
Write-Host "  Paste it inside the ""mcpServers"" block, then restart Claude Desktop." -ForegroundColor DarkGray
Write-Host ""
