#!/bin/bash
# BBW2 P8/P9 排针巡检 · TUI v2（两段式：先全图高亮找脚 → 再命令流回显）
#
# 用法（root，需 tty）：./bbw2-gpio-tui.sh
# 屏 1（接线）：目标排针全图，本对两个脚反白高亮（►xx◄）+ 物理位置提示
# 屏 2（执行）：逐条命令回显（gpioset/gpioget 与对端读数）+ 判定横幅
# 逻辑与 bbw2-gpio-test.sh 同源（DB/配对/双向/AB轮/复测环/SEL恢复）
LOG=/root/gpio-test.log
gs(){ timeout -s INT 0.5 gpioset "$@" 2>/dev/null; }
rd(){ gpioget --numeric -c gpiochip$1 $2 2>/dev/null; }

if tput sgr0 >/dev/null 2>&1; then
	C_HDR=$(tput setaf 6; tput bold); C_OK=$(tput setaf 2; tput bold)
	C_BAD=$(tput setaf 1; tput bold); C_NOTE=$(tput setaf 3)
	C_DIM=$(tput dim); C_OFF=$(tput sgr0); C_REV=$(tput smso)
else
	C_HDR=""; C_OK=""; C_BAD=""; C_NOTE=""; C_DIM=""; C_OFF=""; C_REV=""
fi

declare -A LA LB NOTE SLAB
while read -r p a b; do
	[ -n "$p" ] || continue
	LA[$p]=$a; LB[$p]=$b
done <<'EOF'
P8_3 3:89 -
P8_4 4:3 -
P8_5 3:90 -
P8_6 4:4 -
P8_7 2:1 3:91
P8_8 4:5 -
P8_9 2:11 4:0
P8_10 4:6 -
P8_11 3:25 -
P8_12 3:26 -
P8_13 3:29 4:14
P8_14 3:28 -
P8_15 3:23 -
P8_16 3:24 -
P8_17 3:27 -
P8_18 3:38 -
P8_19 3:30 4:13
P8_20 4:1 -
P8_21 3:87 -
P8_22 4:2 -
P8_23 3:88 -
P8_27 3:63 -
P8_28 3:64 -
P8_29 3:61 -
P8_30 3:62 -
P8_31 3:59 -
P8_32 3:60 -
P8_33 3:58 3:31
P8_34 3:56 -
P8_35 3:57 -
P8_36 3:55 -
P8_37 3:53 2:10
P8_38 3:54 2:9
P8_39 3:51 -
P8_40 3:52 -
P8_41 3:49 -
P8_42 3:50 -
P8_43 3:47 -
P8_44 3:48 -
P8_45 3:45 -
P8_46 3:46 -
P9_11 3:71 -
P9_13 3:72 -
P9_12 2:16 3:14
P9_15 4:16 2:15
P9_17 4:15 4:28
P9_18 4:19 4:29
P9_19 3:43 2:14
P9_20 3:44 2:13
P9_21 4:18 4:8
P9_22 4:17 4:7
P9_24 4:25 3:19
P9_25 3:39 -
P9_26 4:24 -
P9_27 3:20 3:13
P9_28 3:7 3:32
P9_29 3:10 -
P9_30 3:9 3:34
P9_31 3:8 3:35
P9_41 4:30 -
P9_42 3:15 3:13
EOF
while read -r p l; do SLAB[$p]="$l"; done <<'EOF'
P8_1 GND
P8_2 GND
P8_24 MDIO*
P8_25 MDIO*
P8_26 HDMI*
P9_1 GND
P9_2 GND
P9_3 3V3
P9_4 3V3
P9_5 5V
P9_6 5V
P9_7 VS5V
P9_8 VS5V
P9_9 PWR
P9_10 RST
P9_14 HDMI*
P9_16 HDMI*
P9_23 HDMI*
P9_32 AIN7
P9_33 AIN4
P9_34 GND
P9_35 AIN6
P9_36 AIN5
P9_37 AIN2
P9_38 AIN3
P9_39 AIN0
P9_40 AIN1
P9_43 GND
P9_44 GND
P9_45 GND
P9_46 GND
EOF
NOTE[P9_11,P9_12]="P9_11 经 PCA9306（低导通/高上拉）"
NOTE[P9_13,P9_15]="特殊对：两个落单脚互测（搭档为 HDMI 保留）"
NOTE[P9_24,P9_22]="借行：P9_24 搭档 P9_23 是 HDMI 保留，借上行"
NOTE[P9_31,P9_30]="借行：P9_31 搭档 P9_32 是 AIN，借上行"
NOTE[P8_23,P8_22]="借行：P8_23 搭档 P8_24 是 MDIO 活总线，借上行"

PAIRS="P8_3,P8_4 P8_5,P8_6 P8_7,P8_8 P8_9,P8_10 P8_11,P8_12 P8_13,P8_14 P8_15,P8_16 P8_17,P8_18 P8_19,P8_20 P8_21,P8_22 P8_23,P8_22 P8_27,P8_28 P8_29,P8_30 P8_31,P8_32 P8_33,P8_34 P8_35,P8_36 P8_37,P8_38 P8_39,P8_40 P8_41,P8_42 P8_43,P8_44 P8_45,P8_46 P9_11,P9_12 P9_13,P9_15 P9_17,P9_18 P9_19,P9_20 P9_21,P9_22 P9_24,P9_22 P9_25,P9_26 P9_27,P9_28 P9_29,P9_30 P9_31,P9_30 P9_41,P9_42"

rdkey(){	# 无提示单读：归一化（去空白/大小写/首字符），EOF→q；提示由调用方打
	local raw
	if ! read -r raw </dev/tty; then echo q; return; fi
	printf '%s' "$raw" | tr -d '[:space:]' | tr '[:A-Z:'"'"'"]' '[:a-z:'"'"'"]' | cut -c1
}
getline(){ local v; [ "$2" = A ] && v=${LA[$1]} || v=${LB[$1]}
	[ "$v" = "-" -o -z "$v" ] && return 1
	echo "$v"; }
bar(){ local n=$1 t=$2 w=22
	local f=$((n*w/t)); printf '['
	printf '%*s' $f '' | tr ' ' '#'; printf '%*s' $((w-f)) '' | tr ' ' .
	printf ']'; }
hint(){ local n=${1#*_}
	echo "${1%_*}排第$(( (n+1)/2 ))行$([ $((n%2)) = 1 ] && echo 左 || echo 右)"; }
maplab(){	local v=${LA[$1]}
	if [ -n "$v" ]; then
		case ${v%%:*} in 3) echo "G0_${v##*:}";; 4) echo "G1_${v##*:}";; 2) echo "MCU_${v##*:}";; esac
	else echo "${SLAB[$1]:-?}"
	fi; }
hdr_of(){ echo "${1%_*}"; }
LINE46=$(printf '%*s' 72 '' | tr ' ' '-')
dsep(){	# 动态分隔线：宽=标题显示宽（+5 CJK 补偿）；SEPW 由 topbar 设置
	printf '%s%*s%s\n' "$C_DIM" "${1:-$SEPW}" '' "$C_OFF" | tr ' \000' '-\000'; }
topbar(){	# $1轮 $2已测 $3本轮总数
	local T="   BBW2 排针巡检 | $1 轮 $(bar $2 $3) $2/$3  P:$PASS F:$FAIL S:$SKIP"
	SEPW=$(( ${#T} + 5 ))
	dsep
	echo "   ${C_HDR}BBW2 排针巡检${C_OFF}${C_DIM} | $1 轮 $(bar $2 $3) $2/$3  P:$PASS F:$FAIL S:$SKIP${C_OFF}"
	dsep; }

draw_wiring(){	# $1轮 $2已测 $3总数 $4脚a $5脚b（帧高 27 行：标题/提示/地图/底线）
	local R=$1 A=$4 B=$5 H r c pin lab num AN BN
	clear
	H=$(hdr_of $A); AN=${A#*_}; BN=${B#*_}
	echo "${C_DIM}$LINE46${C_OFF}"
	echo "   ${C_HDR}BBW2 排针巡检${C_OFF}${C_DIM} | $R 轮 $(bar $2 $3) $2/$3  P:$PASS F:$FAIL S:$SKIP${C_OFF}"
	echo "${C_DIM}$LINE46${C_OFF}"
	echo ""
	echo "  ${C_NOTE}${H} 排 · 杜邦线插到高亮脚：${C_OFF} ${C_REV}►${AN}◄${C_OFF} 和 ${C_REV}►${BN}◄${C_OFF}"
	[ -n "${NOTE[$A,$B]}" ] && echo "  ${C_NOTE}注: ${NOTE[$A,$B]}${C_OFF}"
	[ "$R" = B ] && echo "  ${C_NOTE}注: B 轮——SEL 已翻转，本屏测另一颗球${C_OFF}"
	for r in $(seq 1 23); do
		printf '  '
		for c in 1 2; do
			num=$(( r*2-2+c ))
			pin="${H}_${num}"
			lab=$(maplab $pin)
			if [ "$pin" = "$A" ] || [ "$pin" = "$B" ]; then
				printf '%s► %-2d %-6s ◄%s   ' "$C_REV" "$num" "$lab" "$C_OFF"
			else
				printf '  %-2d %-6s     ' "$num" "$lab"
			fi
		done
		echo ""
	done
	dsep
	[ -n "$ERRLINE" ] && { echo "  ${C_BAD}$ERRLINE${C_OFF}"; ERRLINE=""; }
}
draw_result(){	# $1轮 $2已测 $3总数 $4脚a $5脚b $6线a $7线b $8判定 $9回显
	local R=$1 A=$4 B=$5 r="$8" E="$9"
	clear
	topbar "$R" "$2" "$3"
	echo ""
	echo "   ${C_BOLD}$A${C_OFF}($6) ${C_NOTE}<==========${C_OFF} ${C_BOLD}$B${C_OFF}($7)"
	echo ""
	# 块宽 = 最长行显示宽（chars + (bytes-chars)/2，CJK 折算），头/尾补齐同宽
	local W=14 L n b
	while IFS= read -r L; do
		[ -z "$L" ] && continue
		n=$(printf '%s' "$L" | wc -m); b=$(printf '%s' "$L" | wc -c)
		[ $(( n + (b-n)/2 )) -gt $W ] && W=$(( n + (b-n)/2 ))
	done <<< "$(echo "$E" | sed 's/^/   /')"
	# 区块头文字居中、头尾与内容严格同宽：以最长内容行为准
	# （内容行 3 空格缩进、头尾 2 空格，尾线取 W-1 使右端与最长行齐平）
	local P=$(( (W-9)/2 ))
	echo "  ${C_DIM}$(printf '%*s' $P '' | tr ' ' '-')终端 log$(printf '%*s' $((W-9-P)) '' | tr ' ' '-')${C_OFF}"
	echo "$E" | sed 's/^/   /'
	echo "  ${C_DIM}$(printf '%*s' $((W-1)) '' | tr ' ' '-')${C_OFF}"
	echo ""
	if [ "${r%%(*}" = PASS ]; then
		echo "   ${C_OK}■ PASS —— 双向通${C_OFF}"
	elif [ "$r" = 跳过 ]; then
		echo "   ${C_DIM}跳过${C_OFF}"
	else
		echo "   ${C_BAD}■ FAIL  $r${C_OFF}"
	fi
	dsep
}
try_pair(){	# 双向验证；stdout=PASS/FAIL(读数) stderr=真实终端log
	local a=$1 b=$2 la=$3 lb=$4 c l x y E=""
	c=${la%%:*}; l=${la##*:}
	E="\$ timeout -s INT 0.5 gpioset -c gpiochip$c $l=1"; gs -c gpiochip$c $l=1
	E="$E"$'\n'"\$ gpioget --numeric -c gpiochip${lb%%:*} ${lb##*:}"; x=$(rd ${lb%%:*} ${lb##*:})
	E="$E"$'\n'"$x"
	E="$E"$'\n'"\$ timeout -s INT 0.5 gpioset -c gpiochip$c $l=0"; gs -c gpiochip$c $l=0
	E="$E"$'\n'"\$ gpioget --numeric -c gpiochip${lb%%:*} ${lb##*:}"; y=$(rd ${lb%%:*} ${lb##*:})
	E="$E"$'\n'"$y"
	E="$E"$'\n'"\$ gpioget -c gpiochip$c $l   # 恢复输入态"
	gpioget -c gpiochip$c $l >/dev/null 2>&1
	if [ "$x$y" != "10" -o -z "$x$y" ]; then echo "$E" >&2; echo "FAIL(读到$x/$y)"; return; fi
	c=${lb%%:*}; l=${lb##*:}
	E="$E"$'\n'"\$ timeout -s INT 0.5 gpioset -c gpiochip$c $l=1"; gs -c gpiochip$c $l=1
	E="$E"$'\n'"\$ gpioget --numeric -c gpiochip${la%%:*} ${la##*:}"; x=$(rd ${la%%:*} ${la##*:})
	E="$E"$'\n'"$x"
	E="$E"$'\n'"\$ timeout -s INT 0.5 gpioset -c gpiochip$c $l=0"; gs -c gpiochip$c $l=0
	E="$E"$'\n'"\$ gpioget --numeric -c gpiochip${la%%:*} ${la##*:}"; y=$(rd ${la%%:*} ${la##*:})
	E="$E"$'\n'"$y"
	E="$E"$'\n'"\$ gpioget -c gpiochip$c $l   # 恢复输入态"
	gpioget -c gpiochip$c $l >/dev/null 2>&1
	echo "$E" >&2
	[ "$x$y" = "10" ] && echo PASS || echo "FAIL(读到$x/$y)"
}
PASS=0; FAIL=0; SKIP=0; DONE=0; TOTAL=$(echo $PAIRS | wc -w)
FDETAIL=(); START=$(date +%s)
run_round(){	# $1=轮名（每轮独立计数：A 分母=全部对，B 分母=含开关脚的对）
	local R=$1 p a b la lb ans r E RT
	DONE=0; RT=0
	for p in $PAIRS; do
		a=${p%,*}; b=${p#*,}
		if [ "$R" = A ] || [ "${LB[$a]}${LB[$b]}" != "--" ]; then RT=$((RT+1)); fi
	done
	echo "== $R 轮 $(date +%H:%M:%S)（$RT 对）==" >> $LOG
	for p in $PAIRS; do
		a=${p%,*}; b=${p#*,}
		if [ "$R" = A ]; then
			la=$(getline $a A); lb=$(getline $b A)
		else
			[ "${LB[$a]}${LB[$b]}" = "--" ] && continue
			la=$(getline $a B) || la=$(getline $a A)
			lb=$(getline $b B) || lb=$(getline $b A)
		fi
		DONE=$((DONE+1))
		draw_wiring "$R" "$DONE" "$RT" "$a" "$b"
		echo -n "   接好线后回车开始 (s=跳过 q=结束): " > /dev/tty
		while :; do
			ans=$(rdkey)
			[ "$ans" = q ] && { DONE=$((DONE-1)); return 2; }
			[ "$ans" = s ] && break
			[ -z "$ans" ] && break
			printf '\033[1A\033[2K' > /dev/tty
			echo -n "  无效输入 '$ans'，可选 s q（回车=开始）—— 重输: " > /dev/tty
		done
		if [ "$ans" = s ]; then
			echo "  跳过 $a<->$b" >> $LOG; SKIP=$((SKIP+1))
			draw_result "$R" "$DONE" "$RT" "$a" "$b" "$la" "$lb" "跳过" ""
			sleep 1; continue
		fi
		r=$(try_pair "$a" "$b" "$la" "$lb" 2>/tmp/tui-err); E=$(cat /tmp/tui-err)
		while :; do
			draw_result "$R" "$DONE" "$RT" "$a" "$b" "$la" "$lb" "$r" "$E"
			if [ "${r%%(*}" = PASS ]; then
				echo "  PASS  $a($la) <-> $b($lb)" >> $LOG; PASS=$((PASS+1))
				echo -n "   回车继续下一对: " > /dev/tty; rdkey >/dev/null; break
			fi
			echo -n "   重插线后回车复测 (f=记失败继续): " > /dev/tty
			while :; do
				ans=$(rdkey)
				[ "$ans" = f ] && break
				[ -z "$ans" ] && break
				printf '\033[1A\033[2K' > /dev/tty
				echo -n "  无效输入 '$ans'，可选 f（回车=重测）—— 重输: " > /dev/tty
			done
			if [ "$ans" = f ]; then
				echo "  FAIL  $a($la) <-> $b($lb) [$r]" >> $LOG; FAIL=$((FAIL+1)); FDETAIL+=("$a($la) <-> $b($lb) $r"); break
			fi
			r=$(try_pair "$a" "$b" "$la" "$lb" 2>/tmp/tui-err); E=$(cat /tmp/tui-err)
		done
	done
}
echo "==== TUI 巡检 $(date '+%F %T') ====" >> $LOG
run_round A; RC=$?
if [ $RC -ne 2 ]; then
	for n in 1 2 3 4 5 6 7 8 9 10 11; do gs EXP_SW_SEL$n=1; done
	run_round B
	for n in 1 2 3 4 5 6 7 8 9 10 11; do gs EXP_SW_SEL$n=0; done
	echo "(SEL 已恢复默认)" >> $LOG
fi
clear
W=46
LINE=$(printf '%*s' $W '' | tr ' ' '-')
echo "$LINE"
echo "   BBW2 排针巡检 · 完成"
echo "$LINE"
printf '   PASS  : %-3d %s\n' "$PASS" "$(printf '%*s' $(( PASS*20/(PASS+FAIL+SKIP+1) )) '' | tr ' ' '#')"
printf '   %sFAIL%s  : %-3d %s\n' "$C_BAD" "$C_OFF" "$FAIL" "$(printf '%*s' $(( FAIL>0 ? FAIL*20/(PASS+FAIL+SKIP+1)+1 : 0 )) '' | tr ' ' '#')"
printf '   %s跳过%s  : %d\n' "$C_DIM" "$C_OFF" "$SKIP"
echo "$LINE"
if [ ${#FDETAIL[@]} -gt 0 ]; then
	echo "   ${C_BAD}失败明细：${C_OFF}"
	for f in "${FDETAIL[@]}"; do echo "     ${C_BAD}x $f${C_OFF}"; done
else
	echo "   ${C_OK}OK 无失败项${C_OFF}"
fi
echo "$LINE"
echo "   用时 : $(( ($(date +%s)-START)/60 )) 分 $(( ($(date +%s)-START)%60 )) 秒"
echo "   明细 : /root/gpio-test.log"
echo "$LINE"
echo "==== 汇总 PASS=$PASS FAIL=$FAIL SKIP=$SKIP ====" >> $LOG
