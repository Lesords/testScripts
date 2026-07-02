#!/bin/sh
# CC33xx WiFi RF test helper for BeagleBadge AM62L.
set -e

usage() {
    cat <<EOF
Usage:
  ./wifi_rf_test.sh                         Show this help
  ./wifi_rf_test.sh check                   ch6, 1-packet link check
  ./wifi_rf_test.sh tx [channel] [seconds]  Continuous packet TX, default ch6/30s
  ./wifi_rf_test.sh tone [channel] [seconds] [offset]
                                            Single tone, default ch6/10s/0
  ./wifi_rf_test.sh stop                    Best-effort stop and leave PLT

Channel/Band mapping:
  2.4 GHz band   BAND=0, channels 1..13, freq_mhz = 2407 + channel * 5
                 examples: ch1=2412, ch6=2437, ch11=2462, ch13=2472
  5 GHz band     BAND=1, channels 36..165, freq_mhz = 5000 + channel * 5
                 examples: ch36=5180, ch40=5200, ch149=5745, ch165=5825

Defaults:
  channel         6
  seconds         tx=30, tone=10, check=1
  BAND            auto from channel when unset; set BAND=0 or BAND=1 to force
  BANDWIDTH       0

Examples:
  ./wifi_rf_test.sh tx 6 30                 2.4 GHz ch6, 2437 MHz, 30s
  ./wifi_rf_test.sh tone 11 10 0            2.4 GHz ch11, 2462 MHz, 10s
  ./wifi_rf_test.sh tx 36 30                5 GHz ch36, 5180 MHz, 30s
  BAND=1 ./wifi_rf_test.sh tx 149 30        Force 5 GHz ch149, 5745 MHz
EOF
}

log() {
    printf '[WiFi-RF] %s\n' "$*"
}

die() {
    printf '[WiFi-RF][ERR] %s\n' "$*" >&2
    exit 1
}

CAL=${CAL:-./calibrator}
IFACE=${IFACE:-wlan0}
BAND=${BAND:-}
BANDWIDTH=${BANDWIDTH:-0}
MODE=${1:-}

case "$MODE" in
    ""|-h|--help|help) usage; exit 0 ;;
    check|tx|tone|stop) ;;
    *) usage; exit 1 ;;
esac

if [ ! -x "$CAL" ]; then
    if [ -x /root/cc33xx/calibrator ]; then
        CAL=/root/cc33xx/calibrator
    elif [ -x /usr/bin/calibrator ]; then
        CAL=/usr/bin/calibrator
    else
        echo "ERROR: calibrator not found" >&2
        exit 1
    fi
fi

to_dec() {
    case "${1:-}" in
        ""|*[!0-9]*) die "invalid number: $1" ;;
    esac
    printf '%s\n' "$1"
}

band_name() {
    case "$1" in
        0) printf '2.4 GHz\n' ;;
        1) printf '5 GHz\n' ;;
        *) printf 'unknown\n' ;;
    esac
}

auto_band_for_channel() {
    ch=$1
    if [ -n "$BAND" ]; then
        case "$BAND" in
            0|1) printf '%s\n' "$BAND"; return ;;
            *) die "BAND must be 0 for 2.4 GHz or 1 for 5 GHz" ;;
        esac
    fi

    if [ "$ch" -ge 1 ] && [ "$ch" -le 13 ]; then
        printf '0\n'
    elif [ "$ch" -ge 36 ] && [ "$ch" -le 165 ]; then
        printf '1\n'
    else
        die "channel out of supported help range: $ch (2.4G: 1..13, 5G: 36..165)"
    fi
}

validate_channel_for_band() {
    ch=$1
    band=$2

    case "$band" in
        0)
            [ "$ch" -ge 1 ] && [ "$ch" -le 13 ] || die "channel $ch is not valid for BAND=0 (2.4 GHz, expected 1..13)"
            ;;
        1)
            [ "$ch" -ge 36 ] && [ "$ch" -le 165 ] || die "channel $ch is not valid for BAND=1 (5 GHz, expected 36..165)"
            ;;
        *)
            die "invalid band: $band"
            ;;
    esac
}

channel_freq_mhz() {
    ch=$1
    band=$2

    case "$band" in
        0) printf '%s\n' "$((2407 + ch * 5))" ;;
        1) printf '%s\n' "$((5000 + ch * 5))" ;;
        *) die "invalid band: $band" ;;
    esac
}

log_channel_params() {
    ch=$1
    band=$2
    freq=$3
    log "channel parameters: channel=$ch, band=$band ($(band_name "$band")), center_freq=${freq}MHz, bandwidth=$BANDWIDTH"
}

stop_services() {
    systemctl stop NetworkManager.service wpa_supplicant.service 2>/dev/null || true
    pkill -x wpa_supplicant 2>/dev/null || true
    ip link set "$IFACE" down 2>/dev/null || ifconfig "$IFACE" down
}

enter_plt() {
    ch=$(to_dec "$1")
    band=$(auto_band_for_channel "$ch")
    validate_channel_for_band "$ch" "$band"
    freq=$(channel_freq_mhz "$ch" "$band")

    log_channel_params "$ch" "$band" "$freq"
    stop_services
    "$CAL" "$IFACE" plt power_mode on
    "$CAL" "$IFACE" cc33xx_plt tune_channel "$ch" "$band" "$BANDWIDTH"
}

leave_plt() {
    "$CAL" "$IFACE" cc33xx_plt stop_tx >/dev/null 2>&1 || true
    "$CAL" "$IFACE" cc33xx_plt tx_tone_stop >/dev/null 2>&1 || true
    "$CAL" "$IFACE" plt power_mode off >/dev/null 2>&1 || true
}

set_tx() {
    pkt_mode=$1
    extra=""
    [ "$pkt_mode" = "2" ] && extra="-num_pkts 1"

    "$CAL" "$IFACE" cc33xx_plt set_manual_calib -tx 1
    "$CAL" "$IFACE" cc33xx_plt set_tx -default 0
    # shellcheck disable=SC2086
    "$CAL" "$IFACE" cc33xx_plt set_tx \
        -preamble_type 2 -phy_rate 5 -tx_power 0 \
        -length const packet 100 -delay 1000 \
        -pkt_mode "$pkt_mode" $extra \
        -data_mode 2 -cca 0 \
        -src_addr 04:05:05:05:05:04 \
        -dst_addr 06:07:07:07:07:06
}

case "$MODE" in
    check)
        trap leave_plt INT TERM EXIT
        log "check parameters: channel=6, packet_count=1, duration=1s, tx_power=0 (calibrator set_tx value)"
        enter_plt 6
        set_tx 2
        "$CAL" "$IFACE" cc33xx_plt start_tx
        sleep 1
        trap - INT TERM EXIT
        leave_plt
        ;;
    tx)
        channel=${2:-6}
        seconds=${3:-30}
        trap leave_plt INT TERM EXIT
        log "TX parameters: channel=$channel, duration=${seconds}s, tx_power=0 (calibrator set_tx value)"
        enter_plt "$channel"
        set_tx 0
        "$CAL" "$IFACE" cc33xx_plt start_tx
        sleep "$seconds"
        trap - INT TERM EXIT
        leave_plt
        ;;
    tone)
        channel=${2:-6}
        seconds=${3:-10}
        offset=${4:-0}
        trap leave_plt INT TERM EXIT
        log "tone parameters: channel=$channel, duration=${seconds}s, offset=$offset"
        enter_plt "$channel"
        "$CAL" "$IFACE" cc33xx_plt tx_start_tone 2 "$offset"
        sleep "$seconds"
        trap - INT TERM EXIT
        leave_plt
        ;;
    stop)
        leave_plt
        ;;
esac
