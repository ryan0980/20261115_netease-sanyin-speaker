# 工具说明

所有 PowerShell 脚本都保持 **ASCII 注释**，因为 Windows PowerShell 5.1 会把无 BOM 的
UTF-8 `.ps1` 按 ANSI 解析，中文注释可能导致语法错误。运行方式：

```powershell
powershell -ExecutionPolicy Bypass -File tools\configure-speaker.ps1
```

| 脚本 | 用途 |
| --- | --- |
| `configure-speaker.ps1` | 向 `192.168.5.1:1705/connect` 发送明文 JSON 配网请求，并观察热点是否消失 |
| `probe-ports.ps1` | 对音箱做 1-65535 全端口 TCP 扫描 |
| `probe-api.ps1` | 探测已知的几个本地 HTTP 接口 |
| `brute-paths.ps1` | 枚举本地 HTTP 路径（404 之外的都算命中） |
| `find-on-lan.ps1` | 在配网后到家庭局域网里找音箱（按端口 + MAC 前缀） |
| `apk/strings.py` | 提取 APK 里所有 dex 字符串（含中文），用于静态分析 |
| `apk/decompile.py` | 用 androguard 反编译指定包名的类（需 `pip install androguard`） |

## 使用前提

- 电脑先连到音箱热点（`网易三音-XXXX`），IP 会拿到 `192.168.5.x`。
- 配网凭据放在仓库根目录 `wifi.txt`（从 `wifi.example.txt` 复制），**不要提交**（已在 `.gitignore`）。
- 这些脚本用原始 TCP 发 HTTP，**不经过系统代理**（避免 `HTTP_PROXY` 干扰）。

## 已知结果（单台设备）

见仓库根目录 README 的「热点模式下开放的服务」「配网接口」「实验记录」三节。
