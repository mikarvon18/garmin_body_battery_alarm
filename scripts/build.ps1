param(
    [Parameter(Mandatory = $true)][string]$SdkPath,
    [Parameter(Mandatory = $true)][string]$DeveloperKey,
    [switch]$Tests
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $SdkPath 'bin\monkeyc.bat'
if (!(Test-Path -LiteralPath $compiler)) { throw "Compiler not found: $compiler" }
if (!(Test-Path -LiteralPath $DeveloperKey)) { throw 'Developer signing key not found.' }
$outputDir = Join-Path $projectRoot 'bin'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$output = Join-Path $outputDir 'Rested.prg'
if ($Tests) { $output = Join-Path $outputDir 'Rested-tests.prg' }
$buildArgs = @('-f', (Join-Path $projectRoot 'monkey.jungle'), '-d', 'venu2', '-y', (Resolve-Path -LiteralPath $DeveloperKey).Path, '-o', $output, '-w')
if ($Tests) { $buildArgs += '-t' }
Push-Location $projectRoot
try {
    & $compiler @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "Monkey C compiler exited with $LASTEXITCODE" }
    Write-Output "Built $output"
} finally { Pop-Location }
