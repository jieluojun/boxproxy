# vpn-src

`decompiled/smali/com/box/app/vpn/` 里的 `VpnPump*`、`VpnTags`、`VpnNet*`、`VpnSb*`、`VpnRoot*`、`SbConfig*`、`XrConfig`、`HyConfig` 的 smali 是由这里的 Java 源码生成的
（apktool 工程里没有 Java 编译步骤，所以提交的是生成物）。

重新生成：

1. `src/` 对着 `stubs/`（只含用到的 Android API 签名，不会进 APK）用 ECJ 编译：
   `-1.8 -proc:none -d cls stubs/**/*.java src/**/*.java`
2. 只把 `com/box/app/vpn/` 下除 stub（`BoxVpnService`、`VpnShell`、`VpnBridge`）以外的 `.class` 交给 D8：
   `--release --min-api 21 --no-desugaring`
3. 用 baksmali（`localsDirective=false; sequentialLabels=false`）反汇编 `classes.dex`，把生成的 smali 覆盖到
   `decompiled/smali/com/box/app/vpn/`。

`stubs/com/box/app/vpn/BoxVpnService.java` 只是编译用的占位，真实类是手写 smali。

`test/`：主机侧测试，不进 APK。`SbConfigTest.java` / `CoreCfgTest.java` 测各内核的配置改写（用 stleary org.json）；
`NetTest.java` + `bridge.py`（`TUNSETIFF` 的 TUN 桥，环境变量 `LOSS` 可丢包）+ `socks.py`（SOCKS5 测试服务，含 UDP）
一起在 Linux 上跑 `VpnNet`（需要 root 建 `tt0`，路由 `203.0.113.0/24`、`198.18.0.0/15` 到它）。


## 配置编辑器的「可视」/「锚点」按钮（`com.box.app.cfg`）

源码在 `cfg/`（Kotlin）：`mishka/` 是 Mishka 引擎原样、`mishka-logic/` 是 `tools/extract_logic.py` 从 Mishka 的 Compose 文件抽出的纯逻辑（生成物，不手改）、
`stubs/` 是编译占位（`CfgGlue`、`Toast`、`Immutable`）、`app/` 是原生 View 界面。生成物在 `decompiled/smali/`
（`com/box/app/cfg`、`top/yukonga`、`kotlin`、`androidx/compose/runtime`）；一键重新生成：`tools/build-cfg.sh`（环境变量见脚本头部）。
流程：kotlinc（`-Xlambdas=class -Xsam-conversions=class`）→ `prune.py` 裁 stdlib 类 → D8（`--no-desugaring`）→ baksmali（`tools/Bk.java`）→ `prune_smali.py` 方法级裁剪。
真实的 `CfgGlue`、`CfgNav`、`CfgIcon`、`CfgClick` 是手写 smali（要碰混淆后的 Compose 与编辑器视图模型 `Lmj5`），不会被脚本覆盖。

### 工具链（不提交二进制）

* Kotlin 编译器：npm `kotlin-compiler`（2.4.x，`package/lib`），用 jdk4py 的 JRE 跑（`KOTLIN_LIB`）。
* 打进 APK 的 stdlib：**npm `kotlin-compiler@1.9.24` 的 `lib/kotlin-stdlib.jar`**（`KOTLIN_STDLIB`）。2.x 的 stdlib 里有 `invokedynamic`（`split` / `lines` / `Regex.findAll` 等），
  `--no-desugaring` 的 D8 不转换、ART 也不支持，运行到就崩；1.9.x 里只剩 `compareBy(vararg)` 一处，源码里避开它即可（`build-cfg.sh` 之后可以 `grep -r invoke-custom decompiled/smali/{kotlin,top,com/box/app/cfg}` 自检）。
* ECJ：npm `@ctxo/lang-java-analyzer` 里的 `jar/ctxo-jdt-analyzer-17.jar`（Eclipse JDT core，带 `batch.Main`，只用来编译 `Bk.java`）。
* android.jar：GitHub `Sable/android-platforms`（`android-33/android.jar`，是真文件不是 LFS）。
* baksmali：npm `apktool-jar@2.4.1` 的 `bin/apktool_2.4.1.jar`（`tools/Bk.java` 调它的 API；`org.jf.baksmali.Main` 没有 main）。
* D8（JVM 版）：沙箱里没有现成的，办法是 npm `d8-termux` 的 `d8.jar`（其实是 dex 版 D8）→ `google/enjarify`
  翻成 JVM jar → `tools/fix_d8_jar.py` 修 class 版本与 InterfaceMethodref → `java -Xverify:none -cp d8fix.jar com.android.tools.r8.D8 …`。
  能用的 D8 jar（Android SDK build-tools 的 `lib/d8.jar`、r8.jar 等）直接用就行。

**sing-box 可视化修改**：`cfg/app/com/box/app/cfg/Sb{Json,Schema,Dialogs,Ui}.kt` + `SbFormActivity`（`Activities.kt`，`AndroidManifest.xml` 里注册）。
入口由 `CfgNav` 在 `CfgGlue.isSingBox` → `EditorGlue.isSingBox(path)`（`.json`/`.jsonc` + 目录 `sing-box`）为真时只挂「可视」图标；`CfgLauncher` 按扩展名分流到 `SbFormActivity`。
schema 由 `tools/gen_sb_schema.py` 从 fork 的 `docs/schema.json` + `option/*.go` + 中文文档生成到 `decompiled/assets/schema/sing-box-fork{,-hints}.json`。
harness：`build.sh` 里的 `SbTest` / `sbflow` / `sb` 随机点击；`pruned.sh` 也跑 `sb`。

## root 模式：外部存储上 boxctl / 核心「Permission denied」

`boxctl` 和核心都在 `Android/data/<包名>/files/box/bin/`（外部存储）。部分机型 / root 方案下 su 看到的 `/storage/emulated/…` 不让执行，报
`…/boxctl: can't execute: Permission denied`，或 boxctl 起核心时 `execute …/bin/mihomo failed: Permission denied (os error 13)`。
同一批文件在真实路径 `/data/media/<用户>/…` 下可以执行。`lb0.c`（拼 boxctl 命令的唯一入口）经 `com.box.app.vpn.BoxctlFix.wrap` 处理：
boxctl 本来能执行就原样运行（不改变现有设备）；否则改用 `/data/media/<用户>/…/bin/boxctl`（chmod 755），并给它 `--home /data/media/<用户>/…/box`，
让它起核心时也走真实路径。开机脚本里同样处理（等待条件由 `-x` 改成 `-f`）。
（早先还试过「复制到应用私有目录 + linker64」和「126 时重试」的回退，真机上只需要走真实路径，已去掉。）**只在一台受影响的真机上验证过。**

## 禁用系统 IPv6：移动网络改为修改 APN（`BoxctlFix`）

`boxctl` 是闭源二进制，「禁用系统 IPv6」是它写 `/proc/sys/net/ipv6/conf/*/disable_ipv6` 实现的。
`BoxctlFix.wrap` 生成的 shell 里加了 `_v6post`，在 `start|restart|boot|stop|reload|mode|network-match|up|down`（`up`/`down` 才是 App 里启动/停止实际发的子命令，`down` 按 stop 处理） 之后执行：

- 判定是否处于“禁用系统 IPv6”：`conf/all` 或 `conf/default` 的 `disable_ipv6` 为 1（`boxctl` 刚写完的结果）。
- 是：把移动网络接口（`rmnet*`、`r_rmnet*`、`ccmni*`、`ccemni*`、`ppp*`、`wwan*`、`seth_*`、`pdp*`）的 `disable_ipv6` 写回 0，WLAN 仍保持 `boxctl` 的禁用；
  再用 `content query/update content://telephony/carriers/preferapn` 把当前 APN 的 `protocol`/`roaming_protocol` 改成 `IP`（IPv4），原值记在 `/data/local/tmp/.boxproxy-apn`。
  APN 在后台改，不拖慢 `restart`；读不到 / 改失败（运营商锁定的 APN）只写一行到 `runs.log`，不影响启动。
- 否（模式改回启用/绕过，或执行了 `stop`）：如果有记录文件，把 APN 还原并删掉记录。

没有改 boxctl 开机脚本（`lb0` 里的 boot 模板）：开机自启仍是 boxctl 原逻辑，下一次从 App 里启动/重启时才会换成 APN 方式。

补充（第二版）：是否“禁用系统 IPv6”改为由 `BoxctlFix.mode` 读 `runtime_profile.ipv6_mode`（只读打开设置库，仅在 start/restart/boot/reload/mode/network-match 命令上读）后以 `_v6m` 传给 shell，读不到才退回 sysctl 状态判断。
找当前 APN 依次试 `preferapn` → `preferapn/subId/<multi_sim_data_call>` → `carriers --where current=1`；写入后读回校验，失败把错误输出写进 `runs.log`；每次触发都会写一行 `移动网络 IPv6: <子命令>: mode=… 处理=…` 方便排查。

调试日志 `boxproxy-v6.log` 写在 `<home>/run/` 下（与 `runs.log` 同目录），不再写 `/data/local/tmp`。
每次 \`up\`/\`start\`/\`restart\` 启动服务前先清空 \`boxproxy-v6.log\`。

第三版：移动网络不再沿用 boxctl 的 sysctl 禁用。`up` 前先记下移动接口的 `accept_ra`（`/data/local/tmp/.boxproxy-v6snap`），boxctl 跑完后把移动接口的 `disable_ipv6` 写回 0、`accept_ra` 还原；
再起一个后台小循环（`/data/local/tmp/.boxproxy-v6w` 为令牌，每 3 秒检查一次），改 APN 导致数据重连、新建的移动接口也会被还原；`down` 或模式不再是“禁用”时停止并清掉这两个文件。WLAN 不受影响。
