<#
.LICENSE
Copyright (c) 2026 DLR e.V.

This program and the accompanying materials are made
available under the terms of the Eclipse Public License 2.0
which is available at https://www.eclipse.org/legal/epl-2.0/

SPDX-License-Identifier: EPL-2.0

.SYNOPSIS
Removes generated GEMSTAR and Unreal Engine build artefacts on Windows.

.DESCRIPTION
Removes the project and plugin directories.
#>

[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectDirectory = Split-Path -Parent $PSScriptRoot

function Remove-BuildDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path -PathType Container) {
        if ($PSCmdlet.ShouldProcess($Path, "Delete directory recursively")) {
            Write-Host "Deleting: $Path"
            Remove-Item -LiteralPath $Path -Recurse -Force
        }
    }
}

Write-Host "============================================"
Write-Host "GEMSTAR Cleanup Script"
Write-Host "Project directory: $projectDirectory"
Write-Host "============================================"

Write-Host ""
Write-Host "Deleting Binaries, Intermediate, DerivedDataCache and Output in project root..."
foreach ($directoryName in @("Binaries", "Intermediate", "DerivedDataCache", "Output")) {
    Remove-BuildDirectory -Path (Join-Path $projectDirectory $directoryName)
}

$pluginsDirectory = Join-Path $projectDirectory "Plugins"
Write-Host ""
Write-Host "Deleting Binaries and Intermediate in Plugins\*..."
if (Test-Path -LiteralPath $pluginsDirectory -PathType Container) {
    foreach ($pluginDirectory in Get-ChildItem -LiteralPath $pluginsDirectory -Directory) {
        Remove-BuildDirectory -Path (Join-Path $pluginDirectory.FullName "Binaries")
        Remove-BuildDirectory -Path (Join-Path $pluginDirectory.FullName "Intermediate")
    }
}

$gameFeaturesDirectory = Join-Path $pluginsDirectory "GameFeatures"
Write-Host ""
Write-Host "Deleting Binaries and Intermediate in Plugins\GameFeatures\*..."
if (Test-Path -LiteralPath $gameFeaturesDirectory -PathType Container) {
    foreach ($pluginDirectory in Get-ChildItem -LiteralPath $gameFeaturesDirectory -Directory) {
        Remove-BuildDirectory -Path (Join-Path $pluginDirectory.FullName "Binaries")
        Remove-BuildDirectory -Path (Join-Path $pluginDirectory.FullName "Intermediate")
    }
}

Write-Host ""
Write-Host "Done."
