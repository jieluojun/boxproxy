.class public final Lcom/box/app/vpn/BoxctlFix;
.super Ljava/lang/Object;
.source "BoxctlFix.java"

# root 模式的 boxctl 放在外部存储（/storage/emulated/0/Android/data/<包名>/files/box/bin/boxctl）。有些机型 / root 方案下
# su 看到的 /storage/emulated/… 不让执行（"can't execute: Permission denied"，核心也一样：
# "execute …/bin/mihomo failed: Permission denied"）。同一批文件在真实路径 /data/media/<用户>/… 下可以执行，所以：
#   1) boxctl 本来就能执行 → 原样运行（不改变现有设备的行为）；
#   2) 否则改用真实路径执行 boxctl（chmod 755），并给它 --home /data/media/<用户>/…/box，
#      让它起核心时也走真实路径（<home>/bin/mihomo）。

.method private constructor <init>()V
    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method

# quoted = boxctl 的路径（已经 shell 引号包好），cmd = 原命令 `'<boxctl>' --db '<db>' <子命令>`
.method public static wrap(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
    .locals 4

    if-eqz p0, :cond_raw

    if-eqz p1, :cond_raw

    const-string v0, "_bxe"

    invoke-virtual {p1, p0, v0}, Ljava/lang/String;->replace(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Ljava/lang/String;

    move-result-object v1

    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v3, "_bx="

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v3, "; _o=\"$_bx\"; _hm=; if [ ! -x \"$_o\" ]; then case \"$_o\" in /storage/emulated/*) _a=\"/data/media/${_o#/storage/emulated/}\"; if [ -f \"$_a\" ]; then chmod 755 \"$_a\" >/dev/null 2>&1; if [ -x \"$_a\" ]; then _bx=\"$_a\"; _hm=\"${_a%/bin/boxctl}\"; fi; fi;; esac; fi; _vl(){ _t=\"$(date '+%Y-%m-%d %H:%M:%S') [Info] 移动网络 IPv6: $*\"; echo \"$_t\" >> \"$_rl\" 2>/dev/null; echo \"$_t\" >> \"${_o%/bin/boxctl}/run/boxproxy-v6.log\" 2>/dev/null; }; _venv(){ unset LD_LIBRARY_PATH LD_PRELOAD; export ANDROID_ROOT=\"${ANDROID_ROOT:-/system}\" ANDROID_DATA=\"${ANDROID_DATA:-/data}\" PATH=\"$PATH:/system/bin:/system/xbin\"; }; _vrow(){ if [ -n \"$2\" ]; then _w=\"$(content query --user 0 --uri \"$1\" --projection _id:protocol:roaming_protocol \"$2\" \"$3\" 2>&1 </dev/null | head -n 3)\"; else _w=\"$(content query --user 0 --uri \"$1\" --projection _id:protocol:roaming_protocol 2>&1 </dev/null | head -n 3)\"; fi; _q=\"$(echo \"$_w\" | head -n 1)\"; case \"$_q\" in *_id=*) return 0;; esac; _vl \"查询 $1 $2 $3 结果: $(echo \"${_w:-空输出}\" | tr '\\n' ' ')\"; return 1; }; _vf(){ _vrow content://telephony/carriers/preferapn && return 0; _sb=\"$(settings get global multi_sim_data_call 2>/dev/null)\"; case \"$_sb\" in ''|*[!0-9-]*) ;; *) _vrow \"content://telephony/carriers/preferapn/subId/$_sb\" && return 0;; esac; _vrow content://telephony/carriers --where \"current=1\" && return 0; return 1; }; _vset(){ _e=\"$(content update --user 0 --uri \"content://telephony/carriers/$1\" --bind protocol:s:\"$2\" --bind roaming_protocol:s:\"$3\" 2>&1 </dev/null | head -n 2 | tr '\\n' ' ')\"; _v=\"$(content query --user 0 --uri \"content://telephony/carriers/$1\" --projection protocol 2>&1 </dev/null | head -n 1)\"; case \"$_v\" in *\"protocol=$2\") return 0;; esac; _vl \"写入 APN $1 失败: ${_e:-无输出} / 读回: $_v\"; return 1; }; _vmob(){ case \"$1\" in rmnet*|r_rmnet*|v4-rmnet*|v4-ccmni*|ccmni*|ccemni*|ppp*|wwan*|seth_*|sipa_eth*|pdp*) return 0;; esac; return 1; }; _v6snap(){ _sn=/data/local/tmp/.boxproxy-v6snap; [ -f \"$_sn\" ] && return 0; : > \"$_sn\" 2>/dev/null; for _i in /sys/class/net/*; do _n=\"${_i##*/}\"; if _vmob \"$_n\"; then echo \"$_n $(cat \"/proc/sys/net/ipv6/conf/$_n/accept_ra\" 2>/dev/null)\" >> \"$_sn\" 2>/dev/null; fi; done; }; _v6mob(){ _sn=/data/local/tmp/.boxproxy-v6snap; for _i in /sys/class/net/*; do _n=\"${_i##*/}\"; if _vmob \"$_n\"; then _c=\"/proc/sys/net/ipv6/conf/$_n\"; if [ \"$(cat \"$_c/disable_ipv6\" 2>/dev/null)\" = 1 ]; then echo 0 > \"$_c/disable_ipv6\" 2>/dev/null; fi; _ra=\"$(sed -n \"s/^$_n \\(.*\\)\\$/\\1/p\" \"$_sn\" 2>/dev/null | head -n 1)\"; if [ -n \"$_ra\" ] && [ \"$(cat \"$_c/accept_ra\" 2>/dev/null)\" != \"$_ra\" ]; then echo \"$_ra\" > \"$_c/accept_ra\" 2>/dev/null; fi; fi; done; }; _v6watch(){ _pf=/data/local/tmp/.boxproxy-v6w; _tk=\"$$.$(date +%s).$(cat /proc/sys/kernel/random/uuid 2>/dev/null)\"; echo \"$_tk\" > \"$_pf\" 2>/dev/null; ( while [ \"$(cat \"$_pf\" 2>/dev/null)\" = \"$_tk\" ]; do sleep 3; if [ \"$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)\" != 1 ] && [ \"$(cat /proc/sys/net/ipv6/conf/default/disable_ipv6 2>/dev/null)\" != 1 ]; then break; fi; _v6mob; done ) >/dev/null 2>&1 & }; _v6post(){ _s=\"$1\"; _st=/data/local/tmp/.boxproxy-apn; _rl=\"${_o%/bin/boxctl}/run/runs.log\"; _off=0; if [ \"$_s\" != stop ] && [ \"$_s\" != down ]; then case \"$_v6m\" in disable) _off=1;; '') if [ \"$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)\" = 1 ] || [ \"$(cat /proc/sys/net/ipv6/conf/default/disable_ipv6 2>/dev/null)\" = 1 ]; then _off=1; fi;; esac; fi; _vl \"$_s: mode=${_v6m:-未知} 处理=$_off\"; if [ \"$_off\" != 1 ]; then rm -f /data/local/tmp/.boxproxy-v6w /data/local/tmp/.boxproxy-v6snap; fi; if [ \"$_off\" = 1 ]; then _v6mob; _v6watch; [ -f \"$_st\" ] && return 0; ( _venv; if ! _vf; then _vl \"读不到当前 APN, 未修改: $_q\"; exit 0; fi; _id=\"$(echo \"$_q\" | sed -n 's/.*_id=\\([0-9][0-9]*\\).*/\\1/p')\"; _pr=\"$(echo \"$_q\" | sed -n 's/.*[ ,]protocol=\\([A-Za-z0-9]*\\).*/\\1/p')\"; _rp=\"$(echo \"$_q\" | sed -n 's/.*roaming_protocol=\\([A-Za-z0-9]*\\).*/\\1/p')\"; if [ -z \"$_id\" ] || [ -z \"$_pr\" ]; then _vl \"APN 行无法解析: $_q\"; exit 0; fi; if [ \"$_pr\" = IP ] && { [ -z \"$_rp\" ] || [ \"$_rp\" = IP ]; }; then _vl \"APN $_id 已经是 IPv4\"; exit 0; fi; printf '%s %s %s\\n' \"$_id\" \"$_pr\" \"${_rp:-IP}\" > \"$_st\" 2>/dev/null; if _vset \"$_id\" IP IP; then _vl \"APN $_id 协议 $_pr 改为 IP (WLAN 仍按原逻辑禁用)\"; else rm -f \"$_st\"; fi ) >/dev/null 2>&1 & elif [ -f \"$_st\" ]; then ( _venv; read -r _id _pr _rp < \"$_st\"; rm -f \"$_st\"; if [ -n \"$_id\" ] && [ -n \"$_pr\" ]; then if _vset \"$_id\" \"$_pr\" \"${_rp:-$_pr}\"; then _vl \"已恢复 APN $_id 协议 $_pr\"; fi; fi ) >/dev/null 2>&1 & fi; return 0; }; _bxe(){ _vd=\"${_o%/bin/boxctl}/run/boxproxy-v6.log\"; case \"$3\" in up|start|restart) : > \"$_vd\" 2>/dev/null;; esac; [ \"$(wc -c < \"$_vd\" 2>/dev/null || echo 0)\" -gt 200000 ] && : > \"$_vd\"; case \"$3\" in monitor) ;; *) echo \"$(date '+%F %T') _bxe sub=$3 mode=${_v6m:-未读取}\" >> \"$_vd\" 2>/dev/null;; esac; if [ \"$_v6m\" = disable ]; then case \"$3\" in up|start|restart|boot|reload) _v6snap;; esac; fi; if [ -z \"$_hm\" ]; then \"$_bx\" \"$@\"; else \"$_bx\" --home \"$_hm\" \"$@\"; fi; _rc=$?; case \"$3\" in start|restart|boot|stop|reload|mode|network-match|up|down) _v6post \"$3\";; esac; return $_rc; }; "

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-static {p1}, Lcom/box/app/vpn/BoxctlFix;->mode(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v3

    const-string v0, "_v6m='"

    invoke-virtual {v2, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v0, "'; "

    invoke-virtual {v2, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    return-object p0

    :cond_raw
    return-object p1
.end method

# 只在 start/restart/boot/reload/mode/network-match 这类命令上读 runtime_profile.ipv6_mode（只读打开设置库），
# 读不到返回 ""（shell 里退回用 sysctl 状态判断）。
.method private static mode(Ljava/lang/String;)Ljava/lang/String;
    .locals 6

    const-string v0, ""

    :try_start_0
    const-string v1, "--db '"

    invoke-virtual {p0, v1}, Ljava/lang/String;->indexOf(Ljava/lang/String;)I

    move-result v2

    if-ltz v2, :cond_ret

    add-int/lit8 v2, v2, 0x6

    const/16 v3, 0x27

    invoke-virtual {p0, v3, v2}, Ljava/lang/String;->indexOf(II)I

    move-result v3

    if-ltz v3, :cond_ret

    invoke-virtual {p0, v2, v3}, Ljava/lang/String;->substring(II)Ljava/lang/String;

    move-result-object v4

    add-int/lit8 v3, v3, 0x1

    invoke-virtual {p0, v3}, Ljava/lang/String;->substring(I)Ljava/lang/String;

    move-result-object v5

    invoke-virtual {v5}, Ljava/lang/String;->trim()Ljava/lang/String;

    move-result-object v5

    const-string v1, "(?s)(start|restart|boot|reload|mode|network-match|up|down)( .*)?"

    invoke-virtual {v5, v1}, Ljava/lang/String;->matches(Ljava/lang/String;)Z

    move-result v1

    if-eqz v1, :cond_ret

    const/4 v1, 0x0

    const/4 v2, 0x1

    invoke-static {v4, v1, v2}, Landroid/database/sqlite/SQLiteDatabase;->openDatabase(Ljava/lang/String;Landroid/database/sqlite/SQLiteDatabase$CursorFactory;I)Landroid/database/sqlite/SQLiteDatabase;

    move-result-object v1

    const-string v2, "SELECT ipv6_mode FROM runtime_profile WHERE id=1"

    const/4 v3, 0x0

    invoke-virtual {v1, v2, v3}, Landroid/database/sqlite/SQLiteDatabase;->rawQuery(Ljava/lang/String;[Ljava/lang/String;)Landroid/database/Cursor;

    move-result-object v2

    invoke-interface {v2}, Landroid/database/Cursor;->moveToFirst()Z

    move-result v3

    if-eqz v3, :cond_close

    const/4 v3, 0x0

    invoke-interface {v2, v3}, Landroid/database/Cursor;->getString(I)Ljava/lang/String;

    move-result-object v0

    :cond_close
    invoke-interface {v2}, Landroid/database/Cursor;->close()V

    invoke-virtual {v1}, Landroid/database/sqlite/SQLiteDatabase;->close()V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :cond_ret

    :catch_0
    const-string v0, ""

    :cond_ret
    if-eqz v0, :cond_empty

    const-string v1, "[a-z]{0,16}"

    invoke-virtual {v0, v1}, Ljava/lang/String;->matches(Ljava/lang/String;)Z

    move-result v1

    if-nez v1, :cond_done

    :cond_empty
    const-string v0, ""

    :cond_done
    return-object v0
.end method
