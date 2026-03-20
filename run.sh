#!/bin/bash

WALLET_A=""
WALLET_B=""

BINARY=./aibtc-rust
RUN_A=4
RUN_B=4
SLEEP_AFTER_B=20
CLEAN_EVERY=50

TG_TOKEN=""
TG_CHAT_ID=""

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

mkdir -p logs
GRAND_FOUND=0; FOUND_A=0; FOUND_B=0; CYCLE=1
SESSION_A=0; SESSION_B=0

tg_send() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "text=$1" > /dev/null
}

tg_report_cycle() {
    tg_send "<b>[ AIBTC Worker ]</b>
<b>Cycle #${CYCLE} Selesai</b>

<b>Wallet A :</b> ${SESSION_A} found
<b>Wallet B :</b> ${SESSION_B} found

<b>Total Keseluruhan</b>
Wallet A  : ${FOUND_A}
Wallet B  : ${FOUND_B}
Grand Total : ${GRAND_FOUND}

Waktu : $(date '+%Y-%m-%d %H:%M:%S')"
}

run_wallet_timed() {
    local LABEL=$1
    local ADDR=$2
    local DURATION=$3
    local LOG_FILE="logs/wallet_${LABEL}_cycle${CYCLE}.json"
    local END_TIME=$(( $(date +%s) + DURATION ))
    local SESSION_FOUND=0

    echo -e "\n${CYAN}================================================${NC}"
    echo -e "${BOLD}${CYAN}   CYCLE $CYCLE | Wallet $LABEL | ${DURATION}s${NC}"
    echo -e "${CYAN}   Address : $ADDR${NC}"
    echo -e "${CYAN}================================================${NC}"

    while [ $(date +%s) -lt $END_TIME ]; do
        OUTPUT=$(timeout 5 $BINARY $ADDR 2>&1)

        while IFS= read -r line; do
            ((SESSION_FOUND++))
            ((GRAND_FOUND++))
            [ "$LABEL" = "A" ] && ((FOUND_A++)) || ((FOUND_B++))
            echo "$line" >> $LOG_FILE
            echo -e "${GREEN}[Wallet $LABEL] Session: $SESSION_FOUND | Total: $GRAND_FOUND | $line${NC}"
        done < <(echo "$OUTPUT" | grep 'FOUND')

        if ! echo "$OUTPUT" | grep -q 'FOUND'; then
            if echo "$OUTPUT" | grep -qE '"code":-429|too many requests'; then
                echo -e "${YELLOW}[429] Wallet $LABEL${NC}"
            else
                echo -e "${RED}[FAILED] Wallet $LABEL | $SESSION_FOUND found${NC}"
            fi
        fi
    done

    [ "$LABEL" = "A" ] && SESSION_A=$SESSION_FOUND || SESSION_B=$SESSION_FOUND
    echo -e "${MAGENTA}[DONE] Wallet $LABEL | Session: $SESSION_FOUND | Total: $GRAND_FOUND${NC}"
}

while true; do
    SESSION_A=0; SESSION_B=0

    run_wallet_timed "A" $WALLET_A $RUN_A
    run_wallet_timed "B" $WALLET_B $RUN_B

    # Hapus log setiap CLEAN_EVERY cycle
    if (( CYCLE % CLEAN_EVERY == 0 )); then
        rm -f logs/*.json
        echo -e "${YELLOW}[CLEAN] Log dihapus di cycle ${CYCLE}${NC}"
    fi

    # Countdown jeda
    echo -e "\n${YELLOW}[JEDA] ${SLEEP_AFTER_B}s...${NC}"
    for i in $(seq $SLEEP_AFTER_B -1 1); do
        echo -ne "${YELLOW}  Lanjut dalam ${i}s...\r${NC}"
        sleep 1
    done

    # Report Telegram setelah jeda selesai
    tg_report_cycle

    ((CYCLE++))
    echo -e "\n${BOLD}${CYAN}[CYCLE $CYCLE] Dimulai!${NC}"
done
