#requires -Version 5.1
<#
.SYNOPSIS
    Probe the Sanyin speaker's local HTTP API (raw TCP HTTP, ignores system proxies).

.DESCRIPTION
    Known endpoints on 192.168.5.1:1705:
      GET  /connect        -> 405 Method Not Allowed
      POST /connect        -> JSON body {"ssid","pwd","account"} -> {"code":1000,...}
      POST /test           -> {"code":200,"data":{...}}
      GET  /system/scan    -> empty response (unconfirmed)

.NOTES
    ASCII only on purpose: Windows PowerShell 5.1 reads UTF-8 .ps1 without BOM as ANSI.
#>
param(
    [string]$Speaker = '192.168.5.1',
    [int[]]$Ports = @(1705, 6060)
)

function Send-Raw([string]$ip, [int]$port, [string]$request, [int]$timeoutMs = 2000) {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $ar = $client.BeginConnect($ip, $port, $null, $null)
        if (-not $ar.AsyncWaitHandle.WaitOne($timeoutMs)) { return 'CONNECT-TIMEOUT' }
        $client.EndConnect($ar)
        $stream = $client.GetStream()
        $stream.ReadTimeout = 1200
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

function Short([string]$s) {
    if ($null -eq $s) { return '' }
    $s = $s -replace "`r", '' -replace "`n", ' | '
    if ($s.Length -gt 600) { return $s.Substring(0, 600) + '...' }
    return $s
}

$dummy = '{"ssid":"test-ssid","pwd":"test-pwd","account":""}'

foreach ($port in $Ports) {
    Write-Host "=== port $port ===" -ForegroundColor Cyan
    $hostHdr = "${Speaker}:${port}"

    $tests = @(
        @('GET', '/', ''),
        @('GET', '/connect', ''),
        @('GET', '/test', ''),
        @('GET', '/system/scan', ''),
        @('POST', '/test', '{}'),
        @('POST', '/connect', $dummy)
    )
    foreach ($t in $tests) {
        $req = $t[0] + ' ' + $t[1] + " HTTP/1.1`r`n" +
            "Host: $hostHdr`r`n" +
            "User-Agent: okhttp/3.12.0`r`n" +
            "Accept: */*`r`n" +
            "Connection: close`r`n"
        if ($t[2]) {
            $req += "Content-Type: application/json; charset=utf-8`r`nContent-Length: $([Text.Encoding]::UTF8.GetByteCount($t[2]))`r`n`r`n" + $t[2]
        } else {
            $req += "`r`n"
        }
        Write-Host ("--- {0} {1}://{2}{3}" -f $t[0], 'http', $hostHdr, $t[1])
        Write-Host (Short (Send-Raw $Speaker $port $req))
    }
}
