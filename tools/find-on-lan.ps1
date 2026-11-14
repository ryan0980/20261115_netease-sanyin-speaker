#requires -Version 5.1
<#
.SYNOPSIS
    Find a Sanyin speaker on the local LAN (after it has been provisioned).

.DESCRIPTION
    Looks for the speaker by its known TCP ports (5005 DLNA, 1705/6060 HTTP)
    and by MAC OUI (default prefix 6c:21:a2, adjust if your unit differs).

.NOTES
    ASCII only on purpose: Windows PowerShell 5.1 reads UTF-8 .ps1 without BOM as ANSI.
#>
param(
    [string]$MacPrefix = '6c-21-a2',
    [int[]]$Ports = @(5005, 1705, 6060)
)

function Test-Tcp([string]$ip, [int]$port, [int]$timeoutMs = 350) {
    $c = New-Object Net.Sockets.TcpClient
    try {
        $t = $c.ConnectAsync($ip, $port)
        if ($t.Wait($timeoutMs) -and $c.Connected) { return $true }
    } catch { } finally { $c.Dispose() }
    return $false
}

$nic = [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
    Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' } |
    Select-Object -First 1
if (-not $nic) { throw 'No active network interface' }
$v4 = $nic.GetIPProperties().UnicastAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
$myIp = $v4.Address.ToString()
$p = $myIp -split '\.'
$prefix = $p[0] + '.' + $p[1] + '.' + $p[2]
Write-Host "my ip = $myIp ; scanning $prefix.0/24" -ForegroundColor Cyan

$found = New-Object System.Collections.Generic.List[string]
foreach ($port in $Ports) {
    for ($i = 1; $i -le 254; $i += 64) {
        $end = [Math]::Min($i + 63, 254)
        $pairs = New-Object System.Collections.Generic.List[object]
        $tasks = New-Object System.Collections.Generic.List[System.Threading.Tasks.Task]
        for ($j = $i; $j -le $end; $j++) {
            $ip = "$prefix.$j"
            $client = New-Object Net.Sockets.TcpClient
            $pairs.Add(@($ip, $client))
            try { $tasks.Add($client.ConnectAsync($ip, $port)) } catch { }
        }
        try { [void][System.Threading.Tasks.Task]::WaitAll($tasks.ToArray(), 350) } catch { }
        foreach ($pair in $pairs) {
            try { if ($pair[1].Connected) { $found.Add("$($pair[0]):$port") } } catch { }
            $pair[1].Dispose()
        }
    }
}

$arp = (& arp.exe -a 2>&1 | Out-String)
$macHit = ($arp -split "`n") | Where-Object { $_ -match [regex]::Escape($MacPrefix) }
if ($macHit) { Write-Host "MAC MATCH:" -ForegroundColor Green; $macHit }
if ($found.Count -gt 0) {
    Write-Host "SPEAKER-LIKE hosts (open ports):" -ForegroundColor Green
    $found | Sort-Object -Unique
} else {
    Write-Host 'No speaker-like hosts found.' -ForegroundColor Yellow
}
