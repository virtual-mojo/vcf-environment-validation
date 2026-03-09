<#
.SYNOPSIS
    Internal logging helper for VCF-Environment-Validation module functions.

.DESCRIPTION
    Writes structured log entries to the host and optionally to a log file.
    This is a Private function — it is NOT exported from the module.
    All Public functions should use Write-VCFLog instead of Write-Host/Write-Verbose
    directly so output formatting stays consistent.

.PARAMETER Message
    The message to log.

.PARAMETER Level
    Severity level: INFO, WARN, ERROR, SUCCESS, DEBUG.

.PARAMETER Component
    The calling function or component name (used for context in log output).

.EXAMPLE
    Write-VCFLog -Message "Connecting to host 10.0.0.10" -Level INFO -Component 'Test-VCFHostConnectivity'
#>
function Write-VCFLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO','WARN','ERROR','SUCCESS','DEBUG')]
        [string]$Level = 'INFO',

        [string]$Component = 'VCF-Environment-Validation'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry     = "[$timestamp] [$Level] [$Component] $Message"

    switch ($Level) {
        'INFO'    { Write-Host $entry -ForegroundColor Cyan    }
        'WARN'    { Write-Host $entry -ForegroundColor Yellow  }
        'ERROR'   { Write-Host $entry -ForegroundColor Red     }
        'SUCCESS' { Write-Host $entry -ForegroundColor Green   }
        'DEBUG'   { Write-Verbose $entry                       }
    }

    # If a module-level log path has been set, append to file as well
    if ($Script:VCF-Environment-ValidationConfig -and $Script:VCF-Environment-ValidationConfig.ContainsKey('LogPath') -and
        $Script:VCF-Environment-ValidationConfig.LogPath) {
        Add-Content -Path $Script:VCF-Environment-ValidationConfig.LogPath -Value $entry -ErrorAction SilentlyContinue
    }
}
