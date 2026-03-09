<#
.SYNOPSIS
    Tests TCP port reachability to a target host.

.DESCRIPTION
    Private wrapper around Test-NetConnection that normalises the result
    into a simple [bool] and captures latency. Used by Public network
    validation functions rather than calling Test-NetConnection directly.

.PARAMETER Target
    Hostname or IP address to test.

.PARAMETER Port
    TCP port number.

.PARAMETER TimeoutSeconds
    Connection timeout. Defaults to the module-level config value.

.OUTPUTS
    [PSCustomObject] with properties: Success [bool], LatencyMs [int], Error [string]
#>
function Invoke-VCFTcpTest {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [int]$TimeoutSeconds = ($Script:VCF-Environment-ValidationConfig.DefaultTimeoutSeconds ?? 5)
    )

    $result = [PSCustomObject]@{
        Success   = $false
        LatencyMs = -1
        Error     = $null
    }

    try {
        $sw  = [System.Diagnostics.Stopwatch]::StartNew()
        $tcp = [System.Net.Sockets.TcpClient]::new()
        $ar  = $tcp.BeginConnect($Target, $Port, $null, $null)
        $ok  = $ar.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds))
        $sw.Stop()

        if ($ok -and $tcp.Connected) {
            $tcp.EndConnect($ar)
            $result.Success   = $true
            $result.LatencyMs = [int]$sw.ElapsedMilliseconds
        }
        else {
            $result.Error = "TCP connect timed out after $TimeoutSeconds s"
        }
        $tcp.Close()
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}
