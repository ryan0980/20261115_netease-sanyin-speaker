#requires -Version 5.1
<#
.SYNOPSIS
    Enumerate local HTTP API paths on the Sanyin speaker (Go net/http services).

.DESCRIPTION
    Unknown paths answer 404, so any other status means the route exists.
    Default wordlist is generated from prefixes x words, plus some hand-picked paths.

.NOTES
    ASCII only on purpose: Windows PowerShell 5.1 reads UTF-8 .ps1 without BOM as ANSI.
#>
param(
    [string]$Speaker = '192.168.5.1',
    [int[]]$Ports = @(1705, 6060)
)

$bases = 'wifi', 'ssid', 'config', 'conf', 'net', 'network', 'netconfig', 'ap', 'apconfig',
    'connect', 'connection', 'connectwifi', 'setwifi', 'setssid', 'set', 'setup', 'join', 'link',
    'bind', 'device', 'devices', 'info', 'status', 'state', 'system', 'sys', 'version', 'ver',
    'about', 'setting', 'settings', 'api', 'service', 'services', 'cmd', 'command', 'rpc',
    'json', 'rest', 'vbox', 'box', 'speaker', 'sanyin', 'neaudio', 'ne_audio', 'audio', 'voice',
    'ota', 'update', 'upgrade', 'firmware', 'reboot', 'reset', 'restart', 'factory', 'debug',
    'metrics', 'health', 'ping', 'test', 'log', 'logs', 'token', 'auth', 'login', 'pair',
    'provision', 'provisioning', 'smartconfig', 'airkiss', 'uuid', 'mac', 'scan', 'list', 'get'
$prefixes = '', 'api/', 'api/v1/', 'api/v2/', 'v1/', 'v2/', 'device/', 'vbox/', 'system/',
    'net/', 'network/', 'wifi/', 'confignet/', 'provisioning/', 'setup/', 'config/'

$paths = New-Object System.Collections.Generic.List[string]
$paths.Add('/')
foreach ($pfx in $prefixes) {
    foreach ($b in $bases) { $paths.Add('/' + $pfx + $b) }
}
foreach ($extra in '/wifi/set', '/wifi/config', '/wifi/connect', '/wifi/scan', '/wifi/status',
    '/setWifi', '/connectWifi', '/network/config', '/device/wifi', '/device/info',
    '/vbox/config', '/vbox/wifi', '/debug/pprof/', '/debug/pprof/goroutine?debug=1',
    '/debug/pprof/cmdline', '/index.html', '/robots.txt', '/health', '/livez', '/readyz') {
    $paths.Add($extra)
}
$paths = $paths | Select-Object -Unique
Write-Host "paths: $($paths.Count)" -ForegroundColor Cyan

function Send-Raw([string]$ip, [int]$port, [string]$request, [int]$timeoutMs = 900) {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $ar = $client.BeginConnect($ip, $port, $null, $null)
        if (-not $ar.AsyncWaitHandle.WaitOne($timeoutMs)) { return 'CONNECT-TIMEOUT' }
        $client.EndConnect($ar)
        $stream = $client.GetStream()
        $stream.ReadTimeout = 600
        $bytes = [Text.Encoding]::UTF8.GetBytes($request)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
        $ms = New-Object IO.MemoryStream
        $buf = New-Object byte[] 4096
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt $timeoutMs) {
            try {
                $n = $stream.Read($buf, 0, $buf.Length)
                if ($n -le 0) { break }
                $ms.Write($buf, 0, $n)
                if ($ms.Length -gt 4096) { break }
            } catch { break }
        }
        $data = $ms.ToArray()
        if ($data.Length -eq 0) { return 'HTTP/0 EMPTY' }
        return [Text.Encoding]::UTF8.GetString($data)
    } catch {
        return 'ERR'
    } finally {
        $client.Dispose()
    }
}

foreach ($port in $Ports) {
    Write-Host "=== port $port ===" -ForegroundColor Cyan
    foreach ($path in $paths) {
        $req = "GET $path HTTP/1.1`r`nHost: ${Speaker}:${port}`r`nConnection: close`r`n`r`n"
        $resp = Send-Raw $Speaker $port $req
        if ($resp -match '^HTTP/.*\s404') { continue }
        $line = ($resp -split "`n")[0] -replace "`r", ''
        Write-Host ("HIT {0} -> {1}" -f $path, $line) -ForegroundColor Yellow
    }
    Write-Host "port $port done"
}
