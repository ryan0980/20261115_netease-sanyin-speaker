# 关键日志摘录（已脱敏）

> SSID、密码、内网 IP、MAC 已替换为占位符。

## 1. 端口扫描（热点模式，192.168.5.1）

```
OPEN 192.168.5.1:53
FULL SCAN DONE in 135.6s
OPEN PORTS: 53, 1705, 5005, 6060
```

## 2. 端口指纹

```
GET http://192.168.5.1:1705/  ->
HTTP/1.1 404 Not Found
Content-Type: text/plain; charset=utf-8
X-Content-Type-Options: nosniff
404 page not found

GET http://192.168.5.1:5005/  ->
HTTP/1.1 200 OK
Server: UPnP/1.0 DLNADOC/1.50 Platinum/1.0.4.11
...
<friendlyName>三音云音箱-XXXX</friendlyName>
<manufacturer>Netease</manufacturer>
<modelDescription>KPlayer: audio render</modelDescription>
```

## 3. 路径枚举（1705 端口，1454 条路径）

```
HIT /connect      -> HTTP/1.1 405 Method Not Allowed
HIT /test         -> HTTP/1.1 405 Method Not Allowed
HIT /system/scan  -> （空连接）
port 1705 : non-404 hits = 3
```

## 4. 配网请求（成功受理）

```
GET /connect -> HTTP/1.1 405 Method Not Allowed

POST /test -> 200 {"code":200,"data":{"url": "http://mp3.9ku.com/m4a/79882.m4a"}}

POST /connect
body: {"ssid":"<SSID>","pwd":"<PWD>","account":""}
-> HTTP/1.1 200 OK
   {"code":1000,"desc":"netease ihw","err_msg":""}
-> 约 5s 后：WLAN ip 从 192.168.5.3 变为空（热点消失）
```

## 5. 对照实验：Base64 版本（不触发连接）

```
POST /connect
body: {"ssid":"TWlzYWth","pwd":"ODUyMDAyNTg=","account":""}
-> {"code":1000,...}
-> 热点保持 16s 以上不消失，音箱无动作
```

## 6. 配网后局域网检查（失败）

```
arp -a  中无 6c:21:a2:* 设备
TCP 扫描 192.168.31.0/24 的 5005/1705/6060/80：未发现音箱
路由器（小米 192.168.31.1）设备列表中也没有新设备
```

## 7. 路由器侧配置（用于排除）

```
2.4G: SSID=<SSID>, 加密=混合加密(WPA/WPA2个人版), 信道=7, 带宽=20M
5G:   SSID=<SSID>_5G
防蹭网：未开启
```
