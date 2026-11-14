# 协议细节

## 1. 拓扑

```
手机/电脑 --Wi-Fi--> 音箱热点 "网易三音-XXXX"
                     音箱 AP 接口 192.168.5.1（网关 + DHCP + DNS）
```

- 网段固定 `192.168.5.0/24`，DHCP 由音箱提供，租期 1 小时。
- DNS 服务器也是音箱（53 端口），对外部域名返回 `DNS operation refused`，不构成 captive portal。
- 音箱不开 ICMP、AP 模式下无 mDNS/SSDP 广播。

## 2. 端口

| 端口 | 说明 |
| --- | --- |
| 1705 | 配网 HTTP 服务（Go）。`/connect`、`/test` 在此 |
| 6060 | 另一个 Go HTTP 服务（用途未确认，未完成路径枚举） |
| 5005 | DLNA/UPnP MediaRenderer，`friendlyName=三音云音箱-XXXX` |
| 53 | DNS |

## 3. 配网请求

```http
POST /connect HTTP/1.1
Host: 192.168.5.1:1705
Content-Type: application/json
User-Agent: okhttp/3.12.0

{"ssid":"<YOUR_2.4G_SSID>","pwd":"<YOUR_PASSWORD>","account":""}
```

要点：

- **明文**，不要 Base64。Base64 版本返回同样的 `code 1000`，但音箱不会断开热点去连接。
- `account` 可以为空；推测与云端绑定有关（云端已停服）。
- 响应：

```json
{"code":1000,"desc":"netease ihw","err_msg":""}
```

- 错误码参考（来自 App 里的字符串）：`RESP_SSID_NOT_FOUND`、`RESP_WIFI_PWD_ERROR`、
  `RESP_WIFI_BUSY`、`RESP_WIFI_OPERATE_ERROR` 等。

## 4. 其他接口

```
POST /test   -> {"code":200,"data":{"url":"http://mp3.9ku.com/m4a/79882.m4a"}}
GET  /system/scan -> 空响应（未确认）
GET  /connect -> 405 Method Not Allowed
```

## 5. 已知现象

发送正确的 `/connect` 后：

1. 约 5 秒内音箱关闭热点（伴随“叮”一声）；
2. 电脑 Wi-Fi 断开（或自动切回原网络）；
3. 音箱尝试连接指定的 Wi-Fi —— **但实验中没有成功过**（详见 docs/evidence.md）。
