#!/bin/bash

WALLET_A=""

BINARY=./aibtc-rust
RUN_SECONDS=5
SLEEP_AFTER=25
CLEAN_EVERY=50

TG_TOKEN=""
TG_CHAT_ID=""

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

mkdir -p logs
GRAND_FOUND=0; CYCLE=1

tg_send() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "text=$1" > /dev/null
}

tg_report() {
    tg_send "<b>[ AIBTC Worker ]</b>
<b>Cycle #${CYCLE} Selesai</b>

<b>Wallet :</b> ${WALLET_A}
<b>Found  :</b> ${SESSION_FOUND} (session)
<b>Total  :</b> ${GRAND_FOUND}

Waktu : $(date '+%Y-%m-%d %H:%M:%S')"
}

tg_send "<b>[ AIBTC Worker Started ]</b>

Wallet : ${WALLET_A}
Run    : ${RUN_SECONDS}s | Istirahat : ${SLEEP_AFTER}s

Waktu : $(date '+%Y-%m-%d %H:%M:%S')"

while true; do
    SESSION_FOUND=0
    LOG_FILE="logs/cycle_${CYCLE}.json"
    END_TIME=$(( $(date +%s) + RUN_SECONDS ))

    echo -e "\n${CYAN}================================================${NC}"
    echo -e "${BOLD}${CYAN}   CYCLE $CYCLE | Run ${RUN_SECONDS}s | Istirahat ${SLEEP_AFTER}s${NC}"
    echo -e "${CYAN}   Wallet : $WALLET_A${NC}"
    echo -e "${CYAN}================================================${NC}"

    while [ $(date +%s) -lt $END_TIME ]; do
        OUTPUT=$(timeout 5 $BINARY $WALLET_A 2>&1)

        if echo "$OUTPUT" | grep -qE '"code":-429|too many requests'; then
            echo -e "${YELLOW}[429] Rate limit! Tambah istirahat...${NC}"
            END_TIME=$(date +%s)
            SLEEP_AFTER=$(( SLEEP_AFTER + 5 ))
            echo -e "${YELLOW}[AUTO] Sleep dinaikkan jadi ${SLEEP_AFTER}s${NC}"
            break
        fi

        while IFS= read -r line; do
            ((SESSION_FOUND++))
            ((GRAND_FOUND++))
            echo "$line" >> $LOG_FILE
            echo -e "${GREEN}[Cycle $CYCLE] Session: $SESSION_FOUND | Total: $GRAND_FOUND | $line${NC}"
        done < <(echo "$OUTPUT" | grep 'FOUND')

        if ! echo "$OUTPUT" | grep -q 'FOUND'; then
            echo -e "${RED}[FAILED] Session: $SESSION_FOUND | Total: $GRAND_FOUND${NC}"
        fi
    done

    echo -e "${MAGENTA}[DONE] Cycle $CYCLE | Session: $SESSION_FOUND | Total: $GRAND_FOUND${NC}"

    if (( CYCLE % CLEAN_EVERY == 0 )); then
        rm -f logs/*.json
        echo -e "${YELLOW}[CLEAN] Log dihapus cycle ${CYCLE}${NC}"
    fi

    echo -e "\n${YELLOW}[ISTIRAHAT] ${SLEEP_AFTER}s...${NC}"
    for i in $(seq $SLEEP_AFTER -1 1); do
        echo -ne "${YELLOW}  Lanjut dalam ${i}s...\r${NC}"
        sleep 1
    done

    tg_report
    ((CYCLE++))
    echo -e "\n${BOLD}${CYAN}[CYCLE $CYCLE] Dimulai!${NC}"
done
