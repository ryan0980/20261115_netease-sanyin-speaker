#requires -Version 5.1
<#
.SYNOPSIS
    Full TCP port scan of the Sanyin speaker in hotspot mode (default 192.168.5.1).

.DESCRIPTION
    Known result on one unit: 53 (DNS), 1705 (config HTTP), 5005 (DLNA), 6060 (HTTP).
    The speaker does not answer ICMP, so this script only uses TCP.

.NOTES
    ASCII only on purpose: Windows PowerShell 5.1 reads UTF-8 .ps1 without BOM as ANSI.
#>
param(
    [string]$Target = '192.168.5.1',
    [int]$BatchSize = 256,
    [int]$BatchWaitMs = 400
)

$open = New-Object System.Collections.Generic.List[int]
$start = Get-Date
$ports = New-Object System.Collections.Generic.List[int]
for ($p = 1; $p -le 65535; $p++) { $ports.Add($p) }

for ($i = 0; $i -lt $ports.Count; $i += $BatchSize) {
    $end = [Math]::Min($i + $BatchSize - 1, $ports.Count - 1)
    $pairs = New-Object System.Collections.Generic.List[object]
    $tasks = New-Object System.Collections.Generic.List[System.Threading.Tasks.Task]
    for ($k = $i; $k -le $end; $k++) {
        $port = $ports[$k]
        $client = New-Object Net.Sockets.TcpClient
        $pairs.Add(@($port, $client))
        try { $tasks.Add($client.ConnectAsync($Target, $port)) } catch { }
    }
    try { [void][System.Threading.Tasks.Task]::WaitAll($tasks.ToArray(), $BatchWaitMs) } catch { }
    foreach ($pair in $pairs) {
        try { if ($pair[1].Connected) { $open.Add([int]$pair[0]) } } catch { }
        $pair[1].Dispose()
    }
    if (($i % 8192) -eq 0) {
        Write-Host ("  {0}/65535  open={1}  {2:n1}s" -f $i, $open.Count, ((Get-Date) - $start).TotalSeconds)
    }
}

Write-Host ("Full scan done in {0:n1}s" -f ((Get-Date) - $start).TotalSeconds) -ForegroundColor Cyan
Write-Host ("OPEN PORTS on {0}: {1}" -f $Target, (($open | Sort-Object) -join ', ')) -ForegroundColor Green
