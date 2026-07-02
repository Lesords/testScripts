#!/bin/sh
# CC33xx WiFi RF test helper for BeagleBadge AM62L.
set -e

usage() {
    cat <<EOF
Usage:
  ./wifi_rf_test.sh                                Show this help
  ./wifi_rf_test.sh check [mode] [rate]            ch6, 1-packet link check
  ./wifi_rf_test.sh tx [channel] [seconds] [mode] [rate]
                                                   Continuous packet TX, default ch6/30s/g/6m
  ./wifi_rf_test.sh tone [channel] [seconds] [offset]
                                                   Single tone, default ch6/10s/0
  ./wifi_rf_test.sh stop                           Best-effort stop and leave PLT

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
  mode            g
  rate            default by mode: b=1m, g=6m, n20=mcs0, ax20=mcs0
  TX_LENGTH       1500 bytes
  TX_DELAY        50 us
  TX_POWER        0 (-10 dBm by calibrator level table, valid 0..31)

Mode/Rate mapping:
  b               11b long preamble: 1m, 2m, 5.5m, 11m
  g               11g legacy OFDM: 6m, 9m, 12m, 18m, 24m, 36m, 48m, 54m
  n20             11n HT20 mixed mode: mcs0..mcs7
  ax20            11ax HE20 SU: mcs0..mcs7

Examples:
  ./wifi_rf_test.sh tx 6 30                 2.4 GHz ch6, 2437 MHz, g/6m, 30s
  ./wifi_rf_test.sh tx 6 30 b 1m            2.4 GHz ch6, 11b/1 Mbps, 30s
  ./wifi_rf_test.sh tx 6 30 n20 mcs0        2.4 GHz ch6, 11n20/MCS0, 30s
  ./wifi_rf_test.sh tx 6 30 ax20 mcs0       2.4 GHz ch6, 11ax20/MCS0, 30s
  TX_DELAY=1000 TX_LENGTH=100 ./wifi_rf_test.sh tx 6 30 g 6m
  TX_POWER=31 ./wifi_rf_test.sh tx 6 30 g 6m
  ./wifi_rf_test.sh tone 11 10 0            2.4 GHz ch11, 2462 MHz, 10s
  ./wifi_rf_test.sh tx 36 30 g 6m           5 GHz ch36, 5180 MHz, g/6m, 30s
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
TX_LENGTH=${TX_LENGTH:-1500}
TX_DELAY=${TX_DELAY:-50}
TX_POWER=${TX_POWER:-0}

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

normalize_wifi_mode() {
    mode=$(printf '%s' "${1:-g}" | tr 'A-Z' 'a-z')

    case "$mode" in
        b|11b) printf 'b\n' ;;
        g|11g) printf 'g\n' ;;
        n|n20|11n|11n20|ht|ht20) printf 'n20\n' ;;
        ax|ax20|11ax|11ax20|he|he20) printf 'ax20\n' ;;
        *) die "invalid WiFi mode: $1 (expected: b, g, n20, ax20)" ;;
    esac
}

default_rate_for_mode() {
    case "$1" in
        b) printf '1m\n' ;;
        g) printf '6m\n' ;;
        n20|ax20) printf 'mcs0\n' ;;
        *) die "invalid WiFi mode: $1" ;;
    esac
}

preamble_for_mode() {
    case "$1" in
        b) printf '1\n' ;;
        g) printf '2\n' ;;
        n20) printf '3\n' ;;
        ax20) printf '5\n' ;;
        *) die "invalid WiFi mode: $1" ;;
    esac
}

phy_rate_for_mode() {
    mode=$1
    rate=$(printf '%s' "$2" | tr 'A-Z' 'a-z')
    rate=${rate%bps}

    case "$mode" in
        b)
            case "$rate" in
                1|1m) printf '1\n' ;;
                2|2m) printf '2\n' ;;
                5.5|5.5m|5_5|5_5m) printf '3\n' ;;
                11|11m) printf '4\n' ;;
                *) die "invalid 11b rate: $2 (expected: 1m, 2m, 5.5m, 11m)" ;;
            esac
            ;;
        g)
            case "$rate" in
                6|6m) printf '5\n' ;;
                9|9m) printf '6\n' ;;
                12|12m) printf '7\n' ;;
                18|18m) printf '8\n' ;;
                24|24m) printf '9\n' ;;
                36|36m) printf '10\n' ;;
                48|48m) printf '11\n' ;;
                54|54m) printf '12\n' ;;
                *) die "invalid 11g rate: $2 (expected: 6m, 9m, 12m, 18m, 24m, 36m, 48m, 54m)" ;;
            esac
            ;;
        n20|ax20)
            case "$rate" in
                mcs0|0|13) printf '13\n' ;;
                mcs1|1|14) printf '14\n' ;;
                mcs2|2|15) printf '15\n' ;;
                mcs3|3|16) printf '16\n' ;;
                mcs4|4|17) printf '17\n' ;;
                mcs5|5|18) printf '18\n' ;;
                mcs6|6|19) printf '19\n' ;;
                mcs7|7|20) printf '20\n' ;;
                *) die "invalid $mode rate: $2 (expected: mcs0..mcs7)" ;;
            esac
            ;;
        *)
            die "invalid WiFi mode: $mode"
            ;;
    esac
}

resolve_tx_params() {
    TX_WIFI_MODE=$(normalize_wifi_mode "${1:-${WIFI_MODE:-g}}")
    TX_RATE=${2:-${WIFI_RATE:-}}
    [ -n "$TX_RATE" ] || TX_RATE=$(default_rate_for_mode "$TX_WIFI_MODE")
    TX_PREAMBLE_TYPE=$(preamble_for_mode "$TX_WIFI_MODE")
    TX_PHY_RATE=$(phy_rate_for_mode "$TX_WIFI_MODE" "$TX_RATE")
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
    tx_mode=${2:-${WIFI_MODE:-g}}
    tx_rate=${3:-${WIFI_RATE:-}}
    tx_length=$(to_dec "$TX_LENGTH")
    tx_delay=$(to_dec "$TX_DELAY")
    tx_power=$(to_dec "$TX_POWER")
    extra=""
    [ "$pkt_mode" = "2" ] && extra="-num_pkts 1"

    [ "$tx_length" -ge 100 ] && [ "$tx_length" -le 3500 ] || die "TX_LENGTH must be 100..3500 bytes"
    [ "$tx_delay" -ge 50 ] && [ "$tx_delay" -le 1000000 ] || die "TX_DELAY must be 50..1000000 us"
    [ "$tx_power" -ge 0 ] && [ "$tx_power" -le 31 ] || die "TX_POWER must be 0..31"

    resolve_tx_params "$tx_mode" "$tx_rate"
    log "TX waveform: mode=$TX_WIFI_MODE, rate=$TX_RATE, preamble_type=$TX_PREAMBLE_TYPE, phy_rate=$TX_PHY_RATE"
    log "TX packet: length=${tx_length} bytes, delay=${tx_delay}us, power_level=$tx_power"

    "$CAL" "$IFACE" cc33xx_plt set_manual_calib -tx 1
    "$CAL" "$IFACE" cc33xx_plt set_tx -default 0
    # shellcheck disable=SC2086
    "$CAL" "$IFACE" cc33xx_plt set_tx \
        -preamble_type "$TX_PREAMBLE_TYPE" -phy_rate "$TX_PHY_RATE" -tx_power "$tx_power" \
        -length const packet "$tx_length" -delay "$tx_delay" \
        -pkt_mode "$pkt_mode" $extra \
        -data_mode 2 -cca 0 \
        -src_addr 04:05:05:05:05:04 \
        -dst_addr 06:07:07:07:07:06
}

case "$MODE" in
    check)
        tx_mode=${2:-${WIFI_MODE:-g}}
        tx_rate=${3:-${WIFI_RATE:-}}
        trap leave_plt INT TERM EXIT
        log "check parameters: channel=6, packet_count=1, duration=1s, mode=${tx_mode}, rate=${tx_rate:-default}, tx_power=${TX_POWER} (calibrator set_tx level)"
        enter_plt 6
        set_tx 2 "$tx_mode" "$tx_rate"
        "$CAL" "$IFACE" cc33xx_plt start_tx
        sleep 1
        trap - INT TERM EXIT
        leave_plt
        ;;
    tx)
        channel=${2:-6}
        seconds=${3:-30}
        tx_mode=${4:-${WIFI_MODE:-g}}
        tx_rate=${5:-${WIFI_RATE:-}}
        trap leave_plt INT TERM EXIT
        log "TX parameters: channel=$channel, duration=${seconds}s, mode=${tx_mode}, rate=${tx_rate:-default}, tx_power=${TX_POWER} (calibrator set_tx level)"
        enter_plt "$channel"
        set_tx 0 "$tx_mode" "$tx_rate"
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
