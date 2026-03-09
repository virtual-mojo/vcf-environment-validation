#
# Module manifest for VCF-Environment-Validation
# VMware Cloud Foundation Pre-Installation Validation Module
#

@{
    # Module identity
    ModuleVersion     = '0.1.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Your Name'
    CompanyName       = 'Your Organization'
    Copyright         = '(c) 2026. All rights reserved.'
    Description       = 'Pre-installation validation toolkit for VMware Cloud Foundation (VCF). Validates deployment parameter workbooks, network connectivity, and environment readiness before VCF installer appliance deployment.'

    # PowerShell requirements
    PowerShellVersion = '7.0'

    # Dependencies (add as needed)
    # RequiredModules = @(
    #     @{ ModuleName = 'ImportExcel'; ModuleVersion = '7.0.0' }
    # )

    # The RootModule loads everything via the .psm1 loader
    RootModule        = 'VCF-Environment-Validation.psm1'

    # Only Public functions are exported; Private functions are dot-sourced but not listed here.
    # The .psm1 handles the actual export — this acts as documentation.
    FunctionsToExport = @(
        # Workbook / JSON
        'Test-VCFWorkbook'
        'Convert-VCFWorkbookToJson'
        'Test-VCFJson'

        # Network validation
        'Test-VCFNetworkConnectivity'
        'Test-VCFDnsResolution'
        'Test-VCFNtpReachability'

        # Host / infrastructure
        'Test-VCFHostConnectivity'
        'Test-VCFEsxiVersion'

        # Reporting
        'New-VCFValidationReport'
        'Get-VCFValidationSummary'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Module metadata shown in Get-Module / PSGallery
    PrivateData       = @{
        PSData = @{
            Tags         = @('VMware', 'VCF', 'CloudFoundation', 'Validation', 'Pre-Install')
            ReleaseNotes = 'Initial scaffold release.'
        }
    }
}
