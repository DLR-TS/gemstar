<#
.LICENSE
Copyright (c) 2026 DLR e.V.

This program and the accompanying materials are made
available under the terms of the Eclipse Public License 2.0
which is available at https://www.eclipse.org/legal/epl-2.0/

SPDX-License-Identifier: EPL-2.0

.SYNOPSIS
Builds all GEMSTAR third-party dependencies natively on Windows.

.DESCRIPTION
Runs the PowerShell dependency build script of every plugin.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "This script builds native Windows dependencies and must be run on Windows."
}

$projectDirectory = Split-Path -Parent $PSScriptRoot
$dependencyScripts = @(
    "Plugins\gemstar_interfaces\Scripts\build-dependencies.ps1"
    "Plugins\GameFeatures\ue_esmini_feature\Scripts\build-dependencies.ps1"
    "Plugins\GameFeatures\ue_fmi_feature\Scripts\build-dependencies.ps1"
    "Plugins\GameFeatures\ue_sumo_feature\Scripts\build-dependencies.ps1"
)

foreach ($relativePath in $dependencyScripts) {
    $scriptPath = Join-Path $projectDirectory $relativePath
    Write-Host ""
    Write-Host "Running: $relativePath"

    & $scriptPath
    if (-not $?) {
        throw "Dependency build script failed: $scriptPath"
    }
}

Write-Host ""
Write-Host "All Windows dependencies were built successfully."
