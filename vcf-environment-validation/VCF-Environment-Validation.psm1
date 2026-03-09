#Requires -Version 7.0
<#
.SYNOPSIS
    VCF-Environment-Validation — VMware Cloud Foundation Pre-Installation Validation Module.

.DESCRIPTION
    This root module (.psm1) auto-discovers and dot-sources all Private and Public
    function files found under the ./Private and ./Public subdirectories.

    Private functions are loaded but NOT exported.
    Public  functions are loaded AND exported via Export-ModuleMember.

    To add a new function:
      - Drop a .ps1 file into ./Public  (will be exported)
      - Drop a .ps1 file into ./Private (available internally, not exported)
    No other changes are required.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Resolve module root regardless of how the module was imported ─────────────
$ModuleRoot = $PSScriptRoot

# ── Helper: dot-source every .ps1 in a folder ────────────────────────────────
function Import-FunctionFolder {
    param(
        [string]$FolderPath,
        [string]$Visibility   # 'Public' or 'Private' — used only for verbose output
    )

    if (-not (Test-Path $FolderPath)) {
        Write-Verbose "[VCF-Environment-Validation] Folder not found, skipping: $FolderPath"
        return @()
    }

    $files = Get-ChildItem -Path $FolderPath -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
    $names = [System.Collections.Generic.List[string]]::new()

    foreach ($file in $files) {
        try {
            . $file.FullName
            $names.Add([System.IO.Path]::GetFileNameWithoutExtension($file.Name))
            Write-Verbose "[VCF-Environment-Validation] Loaded $Visibility function: $($file.BaseName)"
        }
        catch {
            Write-Warning "[VCF-Environment-Validation] Failed to load $($file.FullName): $_"
        }
    }

    return $names
}

# ── Load Private functions (dot-sourced, not exported) ───────────────────────
$null = Import-FunctionFolder -FolderPath "$ModuleRoot\Private" -Visibility 'Private'

# ── Load Public functions and capture their names for export ─────────────────
$PublicFunctions = Import-FunctionFolder -FolderPath "$ModuleRoot\Public" -Visibility 'Public'

# ── Export only Public functions ──────────────────────────────────────────────
if ($PublicFunctions.Count -gt 0) {
    Export-ModuleMember -Function $PublicFunctions
}

# ── Module-level variables (accessible within the module scope) ───────────────
$Script:VCF-Environment-ValidationConfig = @{
    DefaultTimeoutSeconds = 5
    DefaultRetryCount     = 3
    SupportedWorkbookVersions = @('5.0', '5.1', '5.2')
    RequiredJsonSchemaVersion = '1.0'
}

Write-Verbose "[VCF-Environment-Validation] Module loaded. Public functions: $($PublicFunctions -join ', ')"
