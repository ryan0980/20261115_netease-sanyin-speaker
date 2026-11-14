# APK 反编译发现

## 基本信息

| 项目 | 值 |
| --- | --- |
| 包名 | `com.netease.vbox` |
| 版本 | 1.1.1 |
| 大小 | 22,641,539 字节（21.59 MB） |
| MD5（本仓库分析样本） | `7adb6b75d1e0fb76b71bebe8cdd6e63b` |
| ABI | 仅 `armeabi-v7a`（32 位） |
| 加固 | 网易易盾（`com.netease.nis.wrapper`、`libdexfix.so`） |

> 本仓库**不包含 APK 二进制**（网易版权）。如需复现，请自行获取同版本安装包，
> 校验包名/版本即可。

## 配网相关代码

- `com.netease.vbox.confignet.softap` — 热点配网流程（`SoftAPActivity`、`WifiConnector`、
  `WifiScanner`、`WifiHelper`、`WifiStateWatcher`）
- `com.netease.vbox.confignet.ble` — 蓝牙配网流程
- `com.netease.vbox.confignet.ble.config.model.WifiRequest`：

```java
public class WifiRequest {
    private String account;
    private String pwd;
    private String ssid;

    public WifiRequest(String ssid, String pwd, String account) {
        this.ssid = Base64.encodeToString(ssid.getBytes(), 2);  // NO_WRAP
        this.pwd  = Base64.encodeToString(pwd.getBytes(), 2);
        this.account = account;
    }
}
```

- `WifiResponse`：`code` / `desc` / `errMsg`
- 日志串：`APConfig connectVbox Response:`、`AP get Response: %d`、`AP send failed`、
  `AP配网：收到云信下发的配网消息`

## 关键注意事项

1. 大量方法被易盾 nativize（`private native void a(String p0, String p1);` 等），
   真正拼接 URL 的代码在 native 层，静态反编译看不到。
2. 但**字符串池没有被清除**，因此 `ssid: %s, pwd: %s, uuid: %s`、`AP配网...` 等
   日志字符串仍可从 dex 中提取（见 `tools/apk/strings.py`）。
3. 云端接口（`vbox-server.3.163.com`、`3.163.com/app/confignet/ap` 等）均已不可用，
   App 即便能运行也无法完成云端绑定。
4. App 在 Android 10+ 上有闪退/兼容性问题的用户反馈；若要跑它做对照，
   建议用 Android 7-9 的旧机或模拟器。

## 复现分析

```bash
# 提取 dex 字符串（含中文）
python tools/apk/strings.py /path/to/com.netease.vbox.apk out/
grep -E "配网|connect|ssid" out/all-strings.txt

# 反编译 confignet 包（需要 androguard）
pip install androguard
python tools/apk/decompile.py /path/to/com.netease.vbox.apk out/
```
