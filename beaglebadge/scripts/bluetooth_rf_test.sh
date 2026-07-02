#!/bin/sh
#
# CC33xx BLE RF DTM helper.
#
# This script intentionally does not start normal BLE advertising. It prepares
# hci0 for BLE Direct Test Mode, enables CC33xx BLE PLT mode through calibrator,
# then runs LE TX/RX test commands through hcitool.

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WLAN_IF=${WLAN_IF:-wlan0}
HCI_DEV=${HCI_DEV:-hci0}
CALIBRATOR=${CALIBRATOR:-}
RESTORE=0
TEST_ACTIVE=0

log()
{
	printf '[BT-RF] %s\n' "$*"
}

die()
{
	printf '[BT-RF][ERR] %s\n' "$*" >&2
	exit 1
}

usage()
{
	cat <<'EOF'
Usage:
  bluetooth_rf_test.sh
  bluetooth_rf_test.sh check
  bluetooth_rf_test.sh sweep [seconds] [power_index]
  bluetooth_rf_test.sh tx <channel|freq_mhz> [seconds] [power_index] [packet_len] [payload]
  bluetooth_rf_test.sh rx <channel|freq_mhz> [seconds]
  bluetooth_rf_test.sh prep
  bluetooth_rf_test.sh stop
  bluetooth_rf_test.sh restore

Options:
  --restore        Run start_bluetooth.sh after a test command completes.

Defaults:
  no arguments     Show this help; no RF test is started
  check            TX on 2426 MHz for 1 second at power_index 2
  sweep            TX on 2402, 2426, 2480 MHz
  seconds          1
  power_index      2  (0=0 dBm, 1=5 dBm, 2=10 dBm, 3=20 dBm)
  packet_len       37 bytes
  payload          0  (PRBS9)

Channel/Frequency:
  channel range    0..39
  freq_mhz range   2402..2480 MHz, even values only
  formula          freq_mhz = 2402 + channel * 2
  examples         0=2402, 12=2426, 19=2440, 39=2480
  note             DTM channel is not BLE advertising channel; Adv 37/38/39 map to DTM 0/12/39.

Environment:
  WLAN_IF          WiFi netdev used by calibrator, default wlan0
  HCI_DEV          HCI device, default hci0
  CALIBRATOR       Explicit calibrator path

Examples:
  ./bluetooth_rf_test.sh
  ./bluetooth_rf_test.sh check
  ./bluetooth_rf_test.sh sweep
  ./bluetooth_rf_test.sh tx 0 5 2
  ./bluetooth_rf_test.sh tx 2426 10 2
  ./bluetooth_rf_test.sh rx 2480 10
  ./bluetooth_rf_test.sh --restore sweep 1 2
EOF
}

need_cmd()
{
	command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

to_dec()
{
	v=$(printf '%d' "$1" 2>/dev/null) || die "invalid number: $1"
	printf '%s\n' "$v"
}

byte_hex()
{
	n=$(to_dec "$1")
	min=$2
	max=$3
	name=$4

	[ "$n" -ge "$min" ] && [ "$n" -le "$max" ] || die "$name out of range: $n"
	printf '0x%02x\n' "$n"
}

channel_from_arg()
{
	raw=$(to_dec "$1")

	if [ "$raw" -ge 2402 ] && [ "$raw" -le 2480 ]; then
		delta=$((raw - 2402))
		[ $((delta % 2)) -eq 0 ] || die "BLE frequency must map to 2 MHz channel spacing: $raw"
		ch=$((delta / 2))
	else
		ch=$raw
	fi

	[ "$ch" -ge 0 ] && [ "$ch" -le 39 ] || die "BLE DTM channel out of range 0..39: $ch"
	printf '%s\n' "$ch"
}

channel_freq()
{
	ch=$1
	printf '%s\n' "$((2402 + ch * 2))"
}

power_dbm()
{
	case "$1" in
		0) printf '0 dBm\n' ;;
		1) printf '5 dBm\n' ;;
		2) printf '10 dBm\n' ;;
		3) printf '20 dBm\n' ;;
		*) printf 'unknown\n' ;;
	esac
}

payload_name()
{
	case "$1" in
		0) printf 'PRBS9\n' ;;
		1) printf '11110000\n' ;;
		2) printf '10101010\n' ;;
		3) printf 'PRBS15\n' ;;
		4) printf '11111111\n' ;;
		5) printf '00000000\n' ;;
		6) printf '00001111\n' ;;
		7) printf '01010101\n' ;;
		*) printf 'unknown\n' ;;
	esac
}

log_tx_params()
{
	ch=$1
	seconds=$2
	power=$3
	len=$4
	payload=$5
	freq=$(channel_freq "$ch")
	log "TX parameters: channel=$ch (${freq}MHz), duration=${seconds}s, power_index=$power ($(power_dbm "$power")), packet_len=$len, payload=$payload ($(payload_name "$payload"))"
}

log_rx_params()
{
	ch=$1
	seconds=$2
	freq=$(channel_freq "$ch")
	log "RX parameters: channel=$ch (${freq}MHz), duration=${seconds}s"
}

find_calibrator()
{
	if [ -n "$CALIBRATOR" ]; then
		[ -x "$CALIBRATOR" ] || die "CALIBRATOR is not executable: $CALIBRATOR"
		printf '%s\n' "$CALIBRATOR"
		return
	fi

	if [ -x "$SCRIPT_DIR/calibrator" ]; then
		printf '%s\n' "$SCRIPT_DIR/calibrator"
		return
	fi

	if [ -x "$PWD/calibrator" ]; then
		printf '%s\n' "$PWD/calibrator"
		return
	fi

	if command -v calibrator >/dev/null 2>&1; then
		command -v calibrator
		return
	fi

	die "cannot find calibrator; set CALIBRATOR=/path/to/calibrator"
}

hci_exists()
{
	hciconfig "$HCI_DEV" >/dev/null 2>&1
}

find_cc33xx_debug_dir()
{
	for d in /sys/kernel/debug/ieee80211/phy*/cc33xx; do
		[ -d "$d" ] || continue
		[ -e "$d/ble_enable" ] || continue
		printf '%s\n' "$d"
		return 0
	done
	return 1
}

ensure_hci()
{
	if hci_exists; then
		log "$HCI_DEV already exists"
		return
	fi

	dbg=$(find_cc33xx_debug_dir) || die "cannot find /sys/kernel/debug/ieee80211/phy*/cc33xx/ble_enable"
	log "$HCI_DEV not found, enabling CC33xx BLE through $dbg/ble_enable"
	echo 1 > "$dbg/ble_enable" || die "failed to write $dbg/ble_enable"

	i=0
	while [ "$i" -lt 20 ]; do
		if hci_exists; then
			log "$HCI_DEV is ready"
			return
		fi
		sleep 1
		i=$((i + 1))
	done

	die "$HCI_DEV did not appear after enabling BLE"
}

stop_normal_bluetooth()
{
	if command -v systemctl >/dev/null 2>&1; then
		systemctl stop bluetooth >/dev/null 2>&1 || true
	fi
	pkill -x btmon >/dev/null 2>&1 || true
}

prepare_controller()
{
	log "stopping normal bluetooth users"
	stop_normal_bluetooth
	ensure_hci

	log "clearing normal BLE roles on $HCI_DEV"
	btmgmt -i "$HCI_DEV" power off >/dev/null || die "btmgmt power off failed on $HCI_DEV"
	btmgmt -i "$HCI_DEV" advertising off >/dev/null 2>&1 || true
	btmgmt -i "$HCI_DEV" connectable off >/dev/null 2>&1 || true
	btmgmt -i "$HCI_DEV" bondable off >/dev/null 2>&1 || true
	btmgmt -i "$HCI_DEV" pairable off >/dev/null 2>&1 || true
	btmgmt -i "$HCI_DEV" le on >/dev/null || die "btmgmt le on failed on $HCI_DEV"
	btmgmt -i "$HCI_DEV" power on >/dev/null || die "btmgmt power on failed on $HCI_DEV"

	info=$(btmgmt -i "$HCI_DEV" info 2>&1) || die "btmgmt info failed on $HCI_DEV: $info"
	printf '%s\n' "$info"

	current=$(printf '%s\n' "$info" | awk -F': ' '/current settings:/ { print $2 }')
	for role in advertising connectable bondable; do
		case " $current " in
			*" $role "*) die "$HCI_DEV is still $role; DTM TX/RX would likely fail with status 0x21" ;;
		esac
	done
}

enable_ble_plt()
{
	cal=$(find_calibrator)
	log "enabling CC33xx BLE PLT mode: $cal $WLAN_IF cc33xx_plt ble_plt"
	"$cal" "$WLAN_IF" cc33xx_plt ble_plt || die "calibrator ble_plt failed"
}

hci_cmd()
{
	out=$(hcitool -i "$HCI_DEV" cmd "$@" 2>&1)
	rc=$?
	printf '%s\n' "$out"
	[ "$rc" -eq 0 ] || die "hcitool cmd failed: $*"
	HCI_OUT=$out
}

expect_hex()
{
	label=$1
	pattern=$2

	printf '%s\n' "$HCI_OUT" | grep -qi "$pattern" && return 0

	if printf '%s\n' "$HCI_OUT" | grep -qi '01 1E 20 21'; then
		die "$label failed: status 0x21, normal BLE advertising/connectable role is still active"
	fi

	die "$label failed: expected HCI bytes '$pattern'"
}

set_dtm_power()
{
	power_hex=$(byte_hex "$1" 0 3 "power_index")
	log "setting DTM TX power index $1 ($(power_dbm "$1"))"
	hci_cmd 0x3f 0x0011 "$power_hex"
	expect_hex "set DTM TX power" '11 04 00 11 FC'
}

le_test_end()
{
	log "sending LE Test End"
	hci_cmd 0x08 0x001f
	expect_hex "LE Test End" '01 1F 20 00'
	TEST_ACTIVE=0
}

stop_ble_test()
{
	ensure_hci
	log "sending best-effort LE Test End"
	hcitool -i "$HCI_DEV" cmd 0x08 0x001f || true
	TEST_ACTIVE=0
}

cleanup()
{
	if [ "$TEST_ACTIVE" = 1 ]; then
		hcitool -i "$HCI_DEV" cmd 0x08 0x001f >/dev/null 2>&1 || true
	fi
}

trap cleanup INT TERM EXIT

tx_test()
{
	ch=$(channel_from_arg "$1")
	seconds=${2:-1}
	power=${3:-2}
	len=${4:-37}
	payload=${5:-0}

	seconds=$(to_dec "$seconds")
	[ "$seconds" -ge 1 ] || die "seconds must be >= 1"

	ch_hex=$(byte_hex "$ch" 0 39 "channel")
	len_hex=$(byte_hex "$len" 0 255 "packet_len")
	payload_hex=$(byte_hex "$payload" 0 7 "payload")
	freq=$(channel_freq "$ch")

	prepare_controller
	enable_ble_plt
	set_dtm_power "$power"

	log_tx_params "$ch" "$seconds" "$power" "$len" "$payload"
	log "starting LE TX test"
	hci_cmd 0x08 0x001e "$ch_hex" "$len_hex" "$payload_hex"
	expect_hex "LE Transmitter Test" '01 1E 20 00'
	TEST_ACTIVE=1
	sleep "$seconds"
	le_test_end
	log "TX test completed successfully on ${freq}MHz"
}

rx_test()
{
	ch=$(channel_from_arg "$1")
	seconds=${2:-1}

	seconds=$(to_dec "$seconds")
	[ "$seconds" -ge 1 ] || die "seconds must be >= 1"

	ch_hex=$(byte_hex "$ch" 0 39 "channel")
	freq=$(channel_freq "$ch")

	prepare_controller
	enable_ble_plt

	log_rx_params "$ch" "$seconds"
	log "starting LE RX test"
	hci_cmd 0x08 0x001d "$ch_hex"
	expect_hex "LE Receiver Test" '01 1D 20 00'
	TEST_ACTIVE=1
	sleep "$seconds"
	le_test_end
	log "RX test completed successfully on ${freq}MHz"
}

sweep_test()
{
	seconds=${1:-1}
	power=${2:-2}

	seconds=$(to_dec "$seconds")
	[ "$seconds" -ge 1 ] || die "seconds must be >= 1"

	prepare_controller
	enable_ble_plt
	set_dtm_power "$power"

	for ch in 0 12 39; do
		ch_hex=$(byte_hex "$ch" 0 39 "channel")
		freq=$(channel_freq "$ch")
		log_tx_params "$ch" "$seconds" "$power" 37 0
		log "starting LE TX test"
		hci_cmd 0x08 0x001e "$ch_hex" 0x25 0x00
		expect_hex "LE Transmitter Test" '01 1E 20 00'
		TEST_ACTIVE=1
		sleep "$seconds"
		le_test_end
	done

	log "TX sweep completed successfully"
}

restore_bluetooth()
{
	stop_normal_bluetooth
	if [ -x "$SCRIPT_DIR/start_bluetooth.sh" ]; then
		log "restoring normal BLE mode with $SCRIPT_DIR/start_bluetooth.sh"
		"$SCRIPT_DIR/start_bluetooth.sh"
		return
	fi
	die "cannot restore: $SCRIPT_DIR/start_bluetooth.sh is not executable"
}

check_deps()
{
	[ "$(id -u)" -eq 0 ] || die "run as root"
	need_cmd hciconfig
	need_cmd btmgmt
	need_cmd hcitool
	need_cmd pkill
}

while [ "${1:-}" = "--restore" ]; do
	RESTORE=1
	shift
done

cmd=${1:-}
[ $# -gt 0 ] && shift || true

case "$cmd" in
	""|-h|--help|help)
		usage
		exit 0
		;;
	check)
		check_deps
		tx_test 12 1 2
		if [ "$RESTORE" -eq 1 ]; then
			restore_bluetooth
		fi
		;;
	prep)
		check_deps
		prepare_controller
		enable_ble_plt
		;;
	stop)
		check_deps
		stop_ble_test
		;;
	restore)
		check_deps
		restore_bluetooth
		;;
	sweep)
		check_deps
		sweep_test "$@"
		if [ "$RESTORE" -eq 1 ]; then
			restore_bluetooth
		fi
		;;
	tx)
		check_deps
		[ $# -ge 1 ] || die "tx requires <channel|freq_mhz>"
		tx_test "$@"
		if [ "$RESTORE" -eq 1 ]; then
			restore_bluetooth
		fi
		;;
	rx)
		check_deps
		[ $# -ge 1 ] || die "rx requires <channel|freq_mhz>"
		rx_test "$@"
		if [ "$RESTORE" -eq 1 ]; then
			restore_bluetooth
		fi
		;;
	*)
		usage >&2
		die "unknown command: $cmd"
		;;
esac
