#!/usr/bin/env bash
# eMMC 老化测试:整盘写满 + 读回校验,循环 N 轮,每轮记录健康寄存器(Pre EOL/Life Time)与 dmesg 错误数
# ⚠ 需 SD 卡启动;整盘数据全部破坏(RPMB/boot 分区不受影响),测完重刷;掉电后重跑自动续测
set -euo pipefail

usage() {
    cat <<EOF
用法: $(basename "$0") [选项]

  -n 轮数   测试轮数,每轮 ≈1 次 P/E 寿命消耗(默认 100)
  -d 盘名   目标 eMMC,如 mmcblk0(默认:自动识别唯一的非根 eMMC)
  -y        跳过"输入 YES"确认,无人值守
  -l 目录   日志与断点目录(默认 /root/emmc-aging;产物 aging.csv + 每轮 round-N.log)
  -r        从头重跑(清除断点与历史 CSV/日志)
  -h        本帮助
EOF
}

ROUNDS=100
DEV=""
ASSUME_YES=0
RESET=0
LOGDIR="/root/emmc-aging"
while getopts ":n:d:yl:rh" opt; do
    case "$opt" in
        n) ROUNDS="$OPTARG" ;;
        d) DEV="$OPTARG" ;;
        y) ASSUME_YES=1 ;;
        l) LOGDIR="$OPTARG" ;;
        r) RESET=1 ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

CSV="$LOGDIR/aging.csv"
STATE="$LOGDIR/round.done"
mkdir -p "$LOGDIR"

command -v fio >/dev/null && command -v mmc >/dev/null \
    || { apt-get update -qq && apt-get install -y fio mmc-utils; }

# ---- 目标盘识别:eMMC 的 type=MMC(SD 卡是 SD),排除根盘与 boot 分区 ----
ROOT_DISK="$(findmnt -n -o SOURCE / | sed -E 's|.*(mmcblk[0-9]+).*|\1|')"
cands=()
for d in /sys/block/mmcblk*; do
    name="${d##*/}"
    case "$name" in *boot*) continue ;; esac
    [ "$(cat "$d/device/type" 2>/dev/null)" = "MMC" ] || continue
    [ "$name" != "$ROOT_DISK" ] || continue
    cands+=("$name")
done
if [ -z "$DEV" ]; then
    [ "${#cands[@]}" -eq 1 ] || {
        echo "错误:未唯一确定 eMMC 目标盘,候选:${cands[*]:-无}(根盘 ${ROOT_DISK:-未知}),用 -d mmcblkX 指定"
        exit 1
    }
    DEV="${cands[0]}"
fi
case "$DEV" in
    mmcblk[0-9]) ;;
    *) echo "错误:非法盘名 $DEV"; exit 1 ;;
esac
[ "$DEV" != "$ROOT_DISK" ] || { echo "错误:$DEV 是当前根盘"; exit 1; }
grep -q "^/dev/$DEV" /proc/mounts && { echo "错误:/dev/$DEV 上仍有挂载分区,先 umount"; exit 1; }
grep -q "/dev/$DEV" /proc/swaps  && { echo "错误:/dev/$DEV 在用作 swap"; exit 1; }

# ---- 断点状态:读取/重置 ----
DONE=0
[ -f "$STATE" ] && DONE=$(cat "$STATE")
if [ "$RESET" = "1" ]; then
    rm -f "$STATE" "$CSV" "$LOGDIR"/round-*.log
    DONE=0
    echo "已清除断点与历史记录,从头开始"
fi

# ---- 确认门 ----
SIZE_G=$(( $(cat "/sys/block/$DEV/size") / 2 / 1024 / 1024 ))
echo "=============================================="
echo "目标: /dev/$DEV ($(cat "/sys/block/$DEV/device/name" 2>/dev/null || echo eMMC), ${SIZE_G}GiB) | 轮数: $ROUNDS(≈${ROUNDS} P/E,单轮约 5~20 分钟,取决于盘速)"
[ "$DONE" -gt 0 ] && echo "续跑:已完成 $DONE/$ROUNDS 轮"
echo "⚠ 整盘数据将全部破坏,测完需重刷镜像"
if [ "$DONE" -ge "$ROUNDS" ]; then
    echo "上次已完成 $DONE 轮 ≥ 本次目标 $ROUNDS 轮,无待跑轮次(重新测试加 -r)"
    exit 0
fi
[ "$ASSUME_YES" = "1" ] || { read -r -p "输入 YES 开始: " ok; [ "$ok" = "YES" ] || exit 1; }
echo "=============================================="

# ---- 采样函数 ----
health() {  # ext_csd → "pre_eol,life_a,life_b";兼容两种 mmc-utils 输出格式
    mmc extcsd read "/dev/$DEV" 2>/dev/null | awk '
        {
            l = tolower($0)
            if (l ~ /pre.?eol/)                                { match(l, /0x[0-9a-f]+/); eol = substr(l, RSTART, RLENGTH) }
            if (l ~ /life.?time/ && l ~ /(type|estimation) a/) { match(l, /0x[0-9a-f]+/); la  = substr(l, RSTART, RLENGTH) }
            if (l ~ /life.?time/ && l ~ /(type|estimation) b/) { match(l, /0x[0-9a-f]+/); lb  = substr(l, RSTART, RLENGTH) }
        }
        END { print eol "," la "," lb }'
}
err_cnt() {  # dmesg mmc 错误行数(长测中环形缓冲可能回卷,仅作参考)
    dmesg | grep -icE '(mmc[0-9]+:|mmcblk[0-9]+).*(err|timeout|crc|fail)'
}

# ---- 基线(仅全新开始时记录) ----
[ -f "$CSV" ] || echo "round,secs,bw,pre_eol,life_a,life_b,dmesg_err(total+delta),result" > "$CSV"
trap 'kill "${FIO_PID:-0}" 2>/dev/null; echo; echo "中断,已完成 $DONE/$ROUNDS 轮,重跑脚本自动续测"; exit 130' INT TERM
if [ "$DONE" -eq 0 ] && [ "$(wc -l < "$CSV")" -le 1 ]; then  # 全新开始才记基线(第 1 轮中断重跑不重复记)
    IFS=, read -r EOL LA LB <<< "$(health)"
    echo "0,0,NA,$EOL,$LA,$LB,$(err_cnt),baseline" >> "$CSV"
fi
PREV_ERR=$(err_cnt)

# ---- 主循环:每轮 整盘写 + 读回校验,记一行 CSV;进度按 /sys/block 统计实时刷新 ----
STAT="/sys/block/$DEV/stat"
TOTAL=$(cat "/sys/block/$DEV/size")                 # 目标扇区数
while [ "$DONE" -lt "$ROUNDS" ]; do
    N=$((DONE + 1))
    echo "[$(date '+%F %T')] 第 $N/$ROUNDS 轮:整盘写入 + 读回校验..."
    SECS=$SECONDS
    set -- $(cat "$STAT"); R0=$3; W0=$7              # 基线:已读/已写扇区
    fio --name=age --filename="/dev/$DEV" --rw=write --bs=1M --direct=1 \
        --verify=crc32c --verify_fatal=1 --group_reporting \
        > "$LOGDIR/round-$N.log" 2>&1 &
    FIO_PID=$!
    while kill -0 "$FIO_PID" 2>/dev/null; do         # 写满→切"校验"相位
        set -- $(cat "$STAT")
        WD=$(( $7 - W0 )); RD=$(( $3 - R0 ))
        if [ "$WD" -lt $((TOTAL * 99 / 100)) ]; then PHASE=写入; CUR=$WD; else PHASE=校验; CUR=$RD; fi
        PCT=$(( CUR * 100 / TOTAL )); [ "$PCT" -gt 100 ] && PCT=100
        F=$(( PCT * 30 / 100 ))
        printf '\r  %s [%s%s] %3d%%(已用 %d 分 %02d 秒)  ' "$PHASE" \
            "$(printf '#%.0s' $(seq 1 $F))" "$(printf '.%.0s' $(seq 1 $((30 - F))))" \
            "$PCT" $(( (SECONDS - SECS) / 60 )) $(( (SECONDS - SECS) % 60 ))
        sleep 1
    done
    wait "$FIO_PID" && RESULT=ok || RESULT=FAIL
    printf '\n'
    SECS=$((SECONDS - SECS))
    BW=$(grep -oP 'WRITE: bw=\K[0-9.]+[KMG]iB/s' "$LOGDIR/round-$N.log" | tail -1)
    IFS=, read -r EOL LA LB <<< "$(health)"
    ERR=$(err_cnt); ERRD=$((ERR - PREV_ERR)); PREV_ERR=$ERR
    echo "$N,$SECS,${BW:-NA},$EOL,$LA,$LB,$ERR(+$ERRD),$RESULT" >> "$CSV"
    [ "$RESULT" = "FAIL" ] && { echo "第 $N 轮校验失败,详见 $LOGDIR/round-$N.log"; exit 1; }
    echo "$N" > "$STATE"; DONE=$N
    LEFT=$(( (ROUNDS - DONE) * SECS ))
    printf '[%s] 第 %d 轮完成(%ds,%s),预计剩余 ~%dh%02dm\n' \
        "$(date '+%F %T')" "$N" "$SECS" "${BW:-?}" $((LEFT / 3600)) $((LEFT % 3600 / 60))
done

# ---- 汇总与自动判定(终端表格化呈现;CSV 保持机器格式不变) ----
echo "=============================================="
echo "全部 $ROUNDS 轮完成。基线 vs 末轮:"
awk -F, -v last="$(wc -l < "$CSV")" '
    BEGIN {
        split("5 9 12 7 6 6 10", W, " ")        # 各列宽,仅此一处
        MB = (length("\344\275\240") == 1)      # 探测 awk 方言:gawk 按字符(=1),mawk 按字节(=3)
    }
    function dispw(s,  i, w) {                  # 显示宽度:ASCII 1,CJK 2
        w = 0
        for (i = 1; i <= length(s); i++)
            if (substr(s, i, 1) >= "\200") { w += 2; if (!MB) i += 2 } else w++
        return w
    }
    function pad(s, w,  d) { d = w - dispw(s); return s sprintf("%*s", d > 0 ? d : 0, "") }
    function row(c1, c2, c3, c4, c5, c6, c7, c8) {
        return "  " pad(c1, W[1]) " " pad(c2, W[2]) " " pad(c3, W[3]) " " pad(c4, W[4]) \
               " " pad(c5, W[5]) " " pad(c6, W[6]) " " pad(c7, W[7]) " " c8
    }
    NR == 1  { print row("轮次", "耗时", "带宽", "PreEOL", "LifeA", "LifeB", "ERR(总+增)", "结果") }
    NR == 2 || NR == last {
        t = ($2 > 0) ? int($2/60) "m" sprintf("%02ds", $2 % 60) : "-"
        print row($1, t, $3, $4, $5, $6, $7, $8)
    }' "$CSV"
IFS=, read -r _ _ _ EOL0 LA0 LB0 _ _ <<< "$(sed -n '2p' "$CSV")"
IFS=, read -r _ _ _ EOL1 LA1 LB1 _ _ <<< "$(tail -n 1 "$CSV")"
if [ -n "$EOL1" ] && [ -n "$LA1" ]; then
    DA=$(( LA1 - LA0 )); DB=$(( LB1 - LB0 ))
    echo "Pre EOL $EOL0→$EOL1 | Life A $LA0→$LA1(+$DA 档) | Life B $LB0→$LB1(+$DB 档)"
    if [ "$EOL1" = "0x01" ] && [ "$DA" -le 1 ] && [ "$DB" -le 1 ]; then
        echo "结论: PASS(verify 全过,健康寄存器正常)"
    else
        echo "结论: 需人工复核(Pre EOL 异常或寿命涨幅>1 档,详见 $CSV)"
    fi
else
    echo "结论: 需人工复核(健康寄存器未解析到;手动执行: mmc extcsd read /dev/$DEV | grep -iE 'eol|life')"
fi
