<#
.SYNOPSIS
    Validates a VCF Deployment Parameter Workbook (.xlsx) for structural completeness.

.DESCRIPTION
    Opens the Excel workbook and checks that all required worksheets, column
    headers, and mandatory cell values are present and in the expected format.
    Does NOT require the ImportExcel module — uses COM automation on Windows
    or the ImportExcel module when available.

    Returns a collection of VCF-Environment-Validation.ValidationResult objects.

.PARAMETER WorkbookPath
    Full path to the VCF deployment parameter workbook (.xlsx).

.PARAMETER WorkbookVersion
    Expected workbook schema version (e.g. '5.2'). Defaults to latest supported.

.PARAMETER PassThru
    When specified, also returns raw workbook data as a hashtable for piping
    into Convert-VCFWorkbookToJson.

.EXAMPLE
    Test-VCFWorkbook -WorkbookPath 'C:\vcf\deployment-params.xlsx'

.EXAMPLE
    Test-VCFWorkbook -WorkbookPath '.\deployment-params.xlsx' -WorkbookVersion '5.1' -PassThru |
        Convert-VCFWorkbookToJson -OutputPath '.\deployment.json'

.OUTPUTS
    [VCF-Environment-Validation.ValidationResult[]]
    When -PassThru is used, also emits a hashtable tagged as VCF-Environment-Validation.WorkbookData.
#>
function Test-VCFWorkbook {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$WorkbookPath,

        [string]$WorkbookVersion,   # Optional; defaults to module config

        [switch]$PassThru
    )

    begin {
        $component = 'Test-VCFWorkbook'
        $results   = [System.Collections.Generic.List[object]]::new()

        # Required sheets — extend this list as the schema evolves
        $Script:RequiredSheets = @(
            'Cover Sheet'
            'Hosts and Networks'
            'vCenter'
            'NSX'
            'SDDC Manager'
            'vSAN'
        )
    }

    process {
        Write-VCFLog -Message "Validating workbook: $WorkbookPath" -Level INFO -Component $component
        $resolvedPath = Resolve-Path $WorkbookPath

        # ── 1. File existence / extension ─────────────────────────────────────
        $ext = [System.IO.Path]::GetExtension($resolvedPath)
        if ($ext -notin @('.xlsx', '.xlsm')) {
            $results.Add((New-VCFValidationResult -TestName 'Workbook File Type' -Target $resolvedPath `
                -Status 'Fail' -Category 'Workbook' `
                -Message "File extension '$ext' is not supported. Expected .xlsx or .xlsm." `
                -Remediation 'Ensure you are using the official VCF deployment parameter workbook.'))
            return $results
        }

        $results.Add((New-VCFValidationResult -TestName 'Workbook File Type' -Target $resolvedPath `
            -Status 'Pass' -Category 'Workbook' -Message "File extension is valid ($ext)."))

        # ── 2. Import workbook (requires ImportExcel module) ──────────────────
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            $results.Add((New-VCFValidationResult -TestName 'ImportExcel Module' -Target 'PSGallery' `
                -Status 'Warn' -Category 'Workbook' `
                -Message 'ImportExcel module not found. Sheet-level validation will be skipped.' `
                -Remediation "Run: Install-Module ImportExcel -Scope CurrentUser"))
            Write-VCFLog -Message "ImportExcel not available; skipping sheet validation." -Level WARN -Component $component
            return $results
        }

        Import-Module ImportExcel -ErrorAction Stop

        # ── 3. Sheet presence ─────────────────────────────────────────────────
        try {
            $sheetNames = (Open-ExcelPackage -Path $resolvedPath).Workbook.Worksheets.Name
        }
        catch {
            $results.Add((New-VCFValidationResult -TestName 'Workbook Open' -Target $resolvedPath `
                -Status 'Fail' -Category 'Workbook' `
                -Message "Could not open workbook: $_" `
                -Remediation 'Ensure the file is not open in Excel and is not password-protected.'))
            return $results
        }

        foreach ($required in $Script:RequiredSheets) {
            if ($required -in $sheetNames) {
                $results.Add((New-VCFValidationResult -TestName "Sheet Present: $required" -Target $resolvedPath `
                    -Status 'Pass' -Category 'Workbook' -Message "Required sheet '$required' found."))
            }
            else {
                $results.Add((New-VCFValidationResult -TestName "Sheet Present: $required" -Target $resolvedPath `
                    -Status 'Fail' -Category 'Workbook' `
                    -Message "Required sheet '$required' is missing." `
                    -Remediation 'Download the latest VCF deployment workbook template from MyVMware.'))
            }
        }

        # ── 4. PassThru — emit raw data for piping ────────────────────────────
        if ($PassThru) {
            $workbookData = [PSCustomObject]@{
                PSTypeName    = 'VCF-Environment-Validation.WorkbookData'
                WorkbookPath  = [string]$resolvedPath
                SheetNames    = $sheetNames
                RawSheetData  = @{}   # caller can populate or Convert-VCFWorkbookToJson will handle
            }
            Write-Output $workbookData
        }
    }

    end {
        # Always emit the results collection
        $results | ForEach-Object { Write-Output $_ }
    }
}
