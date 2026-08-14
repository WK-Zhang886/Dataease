param(
    [switch]$CheckOnly,
    [switch]$SkipNpmInstall,
    [switch]$NoBrowser,
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [switch]$FullLint
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$CoreDir = Join-Path $RepoRoot "core"
$BackendDir = Join-Path $CoreDir "core-backend"
$FrontendDir = Join-Path $CoreDir "core-frontend"
$LocalDir = Join-Path $RepoRoot ".local\dataease2.0"
$ToolsDir = Join-Path $RepoRoot ".local\tools"
$DataDir = Join-Path $LocalDir "data"
$ExcelDir = Join-Path $DataDir "excel"
$ReportDir = Join-Path $DataDir "report"
$ExportDir = Join-Path $DataDir "exportData"
$FontDir = Join-Path $DataDir "font"
$StaticResourceDir = Join-Path $DataDir "static-resource"
$LogDir = Join-Path $LocalDir "logs\dataease"
$CacheDir = Join-Path $LocalDir "cache"
$ConfDir = Join-Path $LocalDir "conf"
$DriverDir = Join-Path $RepoRoot "drivers"
$CustomDriverDir = Join-Path $LocalDir "custom-drivers"
$LocalNodeDir = Join-Path $ToolsDir "nodejs"
$H2Main = (Join-Path $LocalDir "desktop").Replace("\", "/")
$H2Engine = (Join-Path $LocalDir "desktop_data").Replace("\", "/")

$BundledMaven = Join-Path $env:USERPROFILE ".m2\wrapper\dists\apache-maven-3.9.16-bin\5grr65jo27hi51sujmtcldfovl\apache-maven-3.9.16\bin\mvn.cmd"

function Write-Step {
    param([string]$Message)
    Write-Host "[DataEase Dev] $Message" -ForegroundColor Cyan
}

function Get-CommandPath {
    param([string]$CommandName)
    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    return $null
}

function Require-Command {
    param(
        [string]$Name,
        [string]$InstallHint
    )
    $path = Get-CommandPath $Name
    if (-not $path) {
        throw "$Name was not found. $InstallHint"
    }
    Write-Host "  OK $Name -> $path"
    return $path
}

function Resolve-Maven {
    $mvn = Get-CommandPath "mvn.cmd"
    if ($mvn) {
        return $mvn
    }

    $mvn = Get-CommandPath "mvn"
    if ($mvn) {
        return $mvn
    }

    if (Test-Path -LiteralPath $BundledMaven) {
        return $BundledMaven
    }

    throw "Maven was not found. Install Maven or configure PATH, then retry."
}

function Quote-Arg {
    param([string]$Value)
    return "'" + ($Value -replace "'", "''") + "'"
}

Write-Step "checking project layout"
if (-not (Test-Path -LiteralPath $BackendDir)) {
    throw "Backend directory not found: $BackendDir"
}
if (-not (Test-Path -LiteralPath $FrontendDir)) {
    throw "Frontend directory not found: $FrontendDir"
}

Write-Step "checking local tools"
Require-Command "java" "Install JDK 21 and make sure java is available in PATH." | Out-Null
$MavenCmd = Resolve-Maven
Write-Host "  OK maven -> $MavenCmd"

$LocalNodeBin = Join-Path $LocalNodeDir "node.exe"
$LocalNpmBin = Join-Path $LocalNodeDir "npm.cmd"
if ((Test-Path -LiteralPath $LocalNodeBin) -and (Test-Path -LiteralPath $LocalNpmBin)) {
    $env:PATH = "$LocalNodeDir;$env:PATH"
    $NodeCmd = $LocalNodeBin
    $NpmCmd = $LocalNpmBin
} else {
    $NodeCmd = Get-CommandPath "node"
    $NpmCmd = Get-CommandPath "npm.cmd"
}

if (-not $NpmCmd) {
    $NpmCmd = Get-CommandPath "npm"
}

if (-not $NodeCmd -or -not $NpmCmd) {
    Write-Host "  Missing node/npm. Install Node.js LTS before starting the frontend." -ForegroundColor Yellow
    if (-not $CheckOnly) {
        throw "Node.js/npm is required for frontend startup."
    }
} else {
    Write-Host "  OK node -> $NodeCmd"
    Write-Host "  OK npm  -> $NpmCmd"
}

Write-Step "ensuring local runtime directories"
$runtimeDirs = @(
    $LocalDir,
    $DataDir,
    $ExcelDir,
    $ReportDir,
    $ExportDir,
    $FontDir,
    $StaticResourceDir,
    $LogDir,
    $CacheDir,
    $ConfDir,
    $CustomDriverDir,
    $ToolsDir
)
foreach ($dir in $runtimeDirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

if ($CheckOnly) {
    Write-Step "check complete"
    Write-Host "Backend:  http://localhost:8100"
    Write-Host "Frontend: http://localhost:8080"
    exit 0
}

if ($BackendOnly -and $FrontendOnly) {
    throw "BackendOnly and FrontendOnly cannot be used together."
}

if (-not $BackendOnly -and -not $SkipNpmInstall -and -not (Test-Path -LiteralPath (Join-Path $FrontendDir "node_modules"))) {
    Write-Step "installing frontend dependencies"
    Push-Location $FrontendDir
    try {
        & $NpmCmd install
    } finally {
        Pop-Location
    }
}

$BackendArgs = @(
    "-pl", "core-backend",
    "-DskipTests",
    "-Dmaven.antrun.skip=true",
    "spring-boot:run",
    "-Dspring-boot.run.profiles=desktop",
    "-Dspring-boot.run.jvmArguments=-Xms512m -Xmx4g",
    "-Dspring-boot.run.arguments=--spring.datasource.url=jdbc:h2:$H2Main;AUTO_SERVER=TRUE;AUTO_RECONNECT=TRUE;MODE=MySQL;CASE_INSENSITIVE_IDENTIFIERS=TRUE;DATABASE_TO_UPPER=FALSE --spring.servlet.multipart.max-file-size=500MB --spring.servlet.multipart.max-request-size=500MB --dataease.path.engine=jdbc:h2:$H2Engine;AUTO_SERVER=TRUE;AUTO_RECONNECT=TRUE;MODE=MySQL;CASE_INSENSITIVE_IDENTIFIERS=TRUE;DATABASE_TO_UPPER=FALSE --logging.file.path=$($LogDir.Replace('\','/')) --dataease.path.excel=$($ExcelDir.Replace('\','/'))/ --dataease.path.report=$($ReportDir.Replace('\','/'))/ --dataease.path.exportData=$($ExportDir.Replace('\','/'))/ --dataease.path.font=$($FontDir.Replace('\','/'))/ --dataease.path.static-resource=$($StaticResourceDir.Replace('\','/'))/ --dataease.path.ehcache=$($CacheDir.Replace('\','/')) --dataease.path.share-secret=$($ConfDir.Replace('\','/'))/share-secret.json --dataease.path.driver=$($DriverDir.Replace('\','/')) --dataease.path.custom-drivers=$($CustomDriverDir.Replace('\','/'))/"
)

$BackendCommand = "Set-Location " + (Quote-Arg $CoreDir) + "; & " + (Quote-Arg $MavenCmd) + " " + (($BackendArgs | ForEach-Object { Quote-Arg $_ }) -join " ")
$FrontendEnv = if ($FullLint) { "0" } else { "1" }
$FrontendCommand = "Set-Location " + (Quote-Arg $FrontendDir) + "; `$env:DATAEASE_FAST_DEV=" + (Quote-Arg $FrontendEnv) + "; & " + (Quote-Arg $NpmCmd) + " run dev:win"

if (-not $FrontendOnly) {
    Write-Step "starting backend window"
    Start-Process powershell.exe -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $BackendCommand)
}

if (-not $BackendOnly) {
    Write-Step "starting frontend window"
    Start-Process powershell.exe -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $FrontendCommand)
}

if (-not $NoBrowser -and -not $BackendOnly) {
    Start-Sleep -Seconds 5
    Start-Process "http://localhost:8080"
}

Write-Step "startup commands dispatched"
Write-Host "Backend:  http://localhost:8100"
Write-Host "Frontend: http://localhost:8080"
