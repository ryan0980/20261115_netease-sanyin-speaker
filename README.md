# 网易三音云音箱（NetEase Sanyin Cloud Speaker）逆向与修复笔记

> 状态：**进行中 / 未完成**（暂存工作）。配网协议已完整打通，但音箱在收到配网请求后始终无法真正加入 2.4GHz Wi-Fi，原因未确定。
> 本文档记录设备热点配网模式的全部端口、接口和实验结论，方便后来者继续。

## 设备与固件信息

| 项目 | 值 |
| --- | --- |
| 产品 | 网易三音云音箱（2018 年发布，已停产停服） |
| 配网热点 SSID | `网易三音-XXXX`（XXXX 为设备 MAC 相关后缀） |
| 热点网段 | `192.168.5.0/24`，网关 = DHCP 服务器 = `192.168.5.1` |
| 热点 MAC（示例） | `6c:21:a2:0d:11:9f` |
| DLNA 设备名 | `三音云音箱-XXXX`（`manufacturer: Netease`） |
| 官方 App | 包名 `com.netease.vbox`，最后版本 v1.1.1（21.59 MB，`armeabi-v7a`） |
| App 加固 | 网易易盾（NIS），核心方法被转为 native（`libdexfix.so`） |
| App 状态 | 已下架/停更，官方客服口径“厂家已停止维护” |

## 热点模式下开放的服务

在热点模式（音箱发出 `网易三音-XXXX` AP）下，对 `192.168.5.1` 做全端口 TCP 扫描（1-65535）：

| 端口 | 协议/服务 | 指纹 |
| --- | --- | --- |
| `53` | DNS 服务器 | 可连接，但对外部域名一律 `DNS operation refused` |
| `1705` | **HTTP（Go net/http）** | 未知路径返回 `404 page not found`；配网接口在这里 |
| `5005` | DLNA / UPnP MediaRenderer | `Server: UPnP/1.0 DLNADOC/1.50 Platinum/1.0.4.11` |
| `6060` | HTTP（Go net/http） | 未完成探测（见“未解决问题”） |

- 音箱**不响应 ICMP**（ping 不通），也不广播 mDNS/SSDP（在 AP 模式下）。
- 默认网关拿到的 MAC 即音箱 MAC，可用于在局域网中识别它。

## 配网接口（已确认）

```
POST http://192.168.5.1:1705/connect
Content-Type: application/json
User-Agent: okhttp/3.12.0

{"ssid":"<你家 2.4G Wi-Fi 名称>","pwd":"<密码>","account":""}
```

- `GET /connect` 返回 `405 Method Not Allowed`（说明路径存在、只接受 POST）。
- **必须是明文** JSON。Base64 编码的 ssid/pwd 版本**不会**触发连接（见 `docs/evidence.md`）。
- 成功响应：

```json
{"code":1000,"desc":"netease ihw","err_msg":""}
```

- 发送后**约 5 秒内音箱会关闭热点**并尝试连接你给的 Wi-Fi（伴随一声“叮”）。
- 其他探测到的接口：
  - `POST /test` → `{"code":200,"data":{"url": "http://mp3.9ku.com/m4a/79882.m4a"}}`
  - `GET /system/scan` → 返回空连接（未确认用途）

### 与官方 App 的对应关系

反编译 `com.netease.vbox` 的 `com.netease.vbox.confignet.softap` 包可得：

- App 日志字符串：`APConfig connectVbox Response`、`AP get Response`、`AP send failed`
- 响应模型 `WifiResponse`：字段 `code` / `desc` / `errMsg`（与上面 JSON 对应）
- 请求模型 `WifiRequest`：字段 `ssid` / `pwd` / `account`，构造时对 ssid/pwd 做 Base64
  （该模型位于 `confignet.ble.config.model` 包，Base64 推测是给 BLE 通道用的；走 HTTP 的
  SoftAP 流程实测需要**明文**）
- 成功码 `1000` 与 App 逻辑一致。

## 实验记录（关键结论）

1. 用正确格式 `POST /connect`（明文 JSON）发送家里 2.4G 的 SSID/密码 → 返回 `code 1000`，
   热点 5 秒后消失，电脑自动切回原网络；但随后在 `192.168.31.0/24` 全量扫描（TCP + ARP）
   找不到音箱，路由器设备列表也没有它。
2. 用手机热点做对照实验：第一次手机热点误设为 5GHz（音箱只支持 2.4G，必然失败）；
   改为 2.4GHz 后重试，手机热点设备列表仍无新设备，音箱只“叮”了一声、无语音播报。
3. `netsh wlan show interfaces` 等需要管理员权限，普通权限下无法读取当前 SSID。

**未解决**：音箱接受了配网数据、也会关闭热点去连接，但始终没有真正关联上任何 2.4G AP。

## 可能的原因（供继续排查）

- 热点参数实际未生效（服务端字段名/格式与预期不同，`code 1000` 可能只是“已受理”）。
- 音箱 STA 模式/射频固件异常（AP 模式正常不等于 STA 正常）。
- 路由器侧限制：WPA/WPA2 混合加密、信道、防蹭网、MAC 黑白名单。
- 配网需要额外的 `account`/绑定信息，缺少时联网流程被中断。

## 下一步建议

1. **确认 2.4GHz**：手机热点要显式设为 2.4GHz + WPA2；用另一台设备验证热点可被老设备连接。
2. **官方 App 对照**：用 adb 把 `com.netease.vbox` v1.1.1 装到旧安卓机（或模拟器）上跑一遍，
   `adb logcat` 抓 `VBox.APConfigFragment` 的日志，看 App 发的完整请求（本仓库不含 APK 二进制）。
3. **抓包**：若能让 App 跑起来，在热点侧抓包即可拿到官方请求的完整格式。
4. **检查 6060 端口**：本仓库的路径枚举脚本没有在 6060 上跑完，值得补测。
5. 若确认音箱 STA 损坏，只能走蓝牙模式使用（音质不受影响，但无法语音点歌/AirPlay/DLNA）。

## 仓库内容

```
README.md                  本文
docs/protocol.md           协议细节与请求/响应
docs/evidence.md           关键日志摘录（已脱敏）
docs/apk-analysis.md       APK 反编译发现与易盾加固说明
tools/configure-speaker.ps1  一键发送配网请求（读 credentials 文件）
tools/probe-ports.ps1      热点端口扫描
tools/probe-api.ps1        配网接口探测
tools/brute-paths.ps1      本地 API 路径枚举
tools/find-on-lan.ps1      在家庭局域网中寻找音箱
tools/apk/*.py             APK 字符串提取 / 反编译脚本
wifi.example.txt           凭据文件模板
```

## 免责声明

- 本项目仅用于**个人设备修复研究**，不包含网易的任何软件二进制（APK 请自行从原渠道获取）。
- 部分结论基于单台设备，不保证适用于所有批次/固件版本。
- 请勿将本仓库用于商业用途或破解他人设备。
