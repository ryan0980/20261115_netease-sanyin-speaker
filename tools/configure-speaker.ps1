#requires -Version 5.1
<#
.SYNOPSIS
    Send Wi-Fi credentials to a NetEase Sanyin cloud speaker that is in SoftAP (hotspot) mode.

.DESCRIPTION
    The speaker's hotspot ("网易三音-XXXX") serves a Go HTTP API on 192.168.5.1:1705.
    Sending a plain-JSON POST to /connect makes the speaker drop its AP and try to join
    the given Wi-Fi. Success response: {"code":1000,"desc":"netease ihw","err_msg":""}.

    This script ONLY sends the request - it does not change your Wi-Fi connection.
    Put the PC on the speaker hotspot first, then run this script.

.PARAMETER CredsFile
    Text file with credentials: line 1 = SSID, line 2 = password.
    Lines starting with '#' and blank lines are ignored. Default: ..\wifi.txt

.PARAMETER Speaker
    Speaker IP in hotspot mode (default 192.168.5.1).

.PARAMETER WatchSeconds
    Seconds to watch for the hotspot to disappear after a successful request (default 90).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\configure-speaker.ps1

.NOTES
    ASCII only on purpose: Windows PowerShell 5.1 reads UTF-8 .ps1 without BOM as ANSI.
#>
param(
    [string]$CredsFile = '',
    [string]$Speaker = '192.168.5.1',
    [int]$Port = 1705,
    [int]$WatchSeconds = 90
)

$ErrorActionPreference = 'Stop'

if (-not $CredsFile) { $CredsFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'wifi.txt' }
if (-not (Test-Path $CredsFile)) { throw "Credentials file not found: $CredsFile (copy wifi.example.txt to wifi.txt and fill it in)" }

$lines = Get-Content -Encoding UTF8 $CredsFile | Where-Object { $_.Trim().Length -gt 0 -and -not $_.TrimStart().StartsWith('#') }
if ($lines.Count -lt 2) { throw "Credentials file needs 2 data lines: SSID then password" }
$ssid = $lines[0].Trim()
$pwd = $lines[1].Trim()
Write-Host "SSID = $ssid" -ForegroundColor Cyan

# --- current Wi-Fi check ---
function Get-WlanIPv4 {
    $nic = [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
        Where-Object { $_.NetworkInterfaceType -eq 'Wireless80211' -and $_.OperationalStatus -eq 'Up' } |
        Select-Object -First 1
    if (-not $nic) { return '' }
    $v4 = $nic.GetIPProperties().UnicastAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
    if ($v4) { return $v4.Address.ToString() }
    return ''
}

$myIp = Get-WlanIPv4
Write-Host "Current Wi-Fi IP = '$myIp' (expected something like 192.168.5.x)" -ForegroundColor Cyan
if ($myIp -and -not $myIp.StartsWith('192.168.5.')) {
    Write-Warning "You do not look connected to the speaker hotspot. Continue anyway? (Ctrl+C to abort)"
    Start-Sleep -Seconds 3
}

function Send-Raw([string]$ip, [int]$port, [string]$request, [int]$timeoutMs = 3000) {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $ar = $client.BeginConnect($ip, $port, $null, $null)
        if (-not $ar.AsyncWaitHandle.WaitOne($timeoutMs)) { return 'CONNECT-TIMEOUT' }
        $client.EndConnect($ar)
        $stream = $client.GetStream()
        $stream.ReadTimeout = 2000
        $bytes = [Text.Encoding]::UTF8.GetBytes($request)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
        $ms = New-Object IO.MemoryStream
        $buf = New-Object byte[] 4096
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt 3500) {
            try {
                $n = $stream.Read($buf, 0, $buf.Length)
                if ($n -le 0) { break }
                $ms.Write($buf, 0, $n)
                if ($ms.Length -gt 8192) { break }
            } catch { break }
        }
        $data = $ms.ToArray()
        if ($data.Length -eq 0) { return 'HTTP/0 EMPTY' }
        return [Text.Encoding]::UTF8.GetString($data)
    } catch {
        return 'ERR: ' + $_.Exception.Message
    } finally {
        $client.Dispose()
    }
}

# --- POST /connect with PLAIN json (this is the important part) ---
$body = '{"ssid":"' + $ssid.Replace('"', '\"') + '","pwd":"' + $pwd.Replace('"', '\"') + '","account":""}'
$request = "POST /connect HTTP/1.1`r`n" +
    "Host: ${Speaker}:${Port}`r`n" +
    "User-Agent: okhttp/3.12.0`r`n" +
    "Accept: */*`r`n" +
    "Content-Type: application/json; charset=utf-8`r`n" +
    "Content-Length: $([Text.Encoding]::UTF8.GetByteCount($body))`r`n" +
    "Connection: close`r`n`r`n" + $body

Write-Host "POST http://${Speaker}:${Port}/connect ..." -ForegroundColor Cyan
$response = Send-Raw $Speaker $Port $request
Write-Host $response

if ($response -match '"code"\s*:\s*1000') {
    Write-Host "Speaker accepted the request (code 1000). It should drop its AP within ~5s." -ForegroundColor Green
} else {
    Write-Host "Unexpected response - check docs/protocol.md" -ForegroundColor Yellow
}

# --- watch for the AP to disappear ---
if ($WatchSeconds -gt 0) {
    Write-Host "Watching for hotspot to disappear ($WatchSeconds s)..." -ForegroundColor Cyan
    $end = (Get-Date).AddSeconds($WatchSeconds)
    $last = $myIp
    while ((Get-Date) -lt $end) {
        Start-Sleep -Seconds 3
        $cur = Get-WlanIPv4
        if ($cur -ne $last) {
            Write-Host "  Wi-Fi IP -> '$cur'"
            $last = $cur
        }
        if (-not $cur -or -not $cur.StartsWith('192.168.5.')) {
            Write-Host "Hotspot gone / joined another network. Check your router's client list." -ForegroundColor Green
            return
        }
    }
    Write-Host "Hotspot still up after $WatchSeconds s - speaker probably failed to join." -ForegroundColor Yellow
}
