param(
    [string]$VivadoPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($VivadoPath)) {
    $vivadoCommand = Get-Command vivado.bat -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $vivadoCommand) {
        $vivadoCommand = Get-Command vivado -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }

    if ($null -ne $vivadoCommand) {
        $VivadoPath = $vivadoCommand.Source
    }
    elseif (![string]::IsNullOrWhiteSpace($env:XILINX_VIVADO)) {
        $VivadoPath = Join-Path $env:XILINX_VIVADO "bin\vivado.bat"
    }
}

if ([string]::IsNullOrWhiteSpace($VivadoPath) -or
    !(Test-Path -LiteralPath $VivadoPath)) {
    throw "Vivado was not found. Add it to PATH, set XILINX_VIVADO, or pass -VivadoPath."
}

$scriptPath = Join-Path $PSScriptRoot "create_pipeline_project.tcl"
$buildPath = Join-Path $PSScriptRoot "build_pipeline"
$userRoot = Join-Path $PSScriptRoot ".vivado_user"
$roamingRoot = Join-Path $userRoot "AppData\Roaming"
$localRoot = Join-Path $userRoot "AppData\Local"

# A project-local profile avoids stale or unwritable user-app data from making
# Vivado fail before it reaches the synthesis Tcl script. It also makes the
# command behave the same way for both project partners.
New-Item -ItemType Directory -Force -Path $roamingRoot | Out-Null
New-Item -ItemType Directory -Force -Path $localRoot | Out-Null

if (Test-Path -LiteralPath $buildPath) {
    Remove-Item -LiteralPath $buildPath -Recurse -Force
}

$env:APPDATA = $roamingRoot
$env:LOCALAPPDATA = $localRoot
$env:HOME = $userRoot

Write-Host "Using Vivado: $VivadoPath"
Write-Host "Synthesis script: $scriptPath"
Write-Host "Vivado user data: $userRoot"

& $VivadoPath -mode batch -source $scriptPath

if ($LASTEXITCODE -ne 0) {
    throw "Vivado pipeline synthesis failed with exit code $LASTEXITCODE."
}

Write-Host "Reports: $(Join-Path $PSScriptRoot 'build_pipeline')"
