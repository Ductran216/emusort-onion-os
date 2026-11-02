#!/bin/sh
export PATH="/mnt/SDCARD/.tmp_update/bin:/bin:/sbin:/usr/bin:/usr/sbin:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/.tmp_update/lib:/lib:/usr/lib:$LD_LIBRARY_PATH"

if [ "$1" != "--tui" ]; then
  mv /dev/input/event0 /dev/input/emusort_ev0 2>/dev/null
  /mnt/SDCARD/.tmp_update/bin/st -q -e /bin/sh "$0" --tui
  mv /dev/input/emusort_ev0 /dev/input/event0 2>/dev/null
  exit 0
fi

if [ -e /dev/input/emusort_ev0 ]; then
  exec 3</dev/input/emusort_ev0
  (usleep 250000 2>/dev/null || sleep 1; mv /dev/input/emusort_ev0 /dev/input/event0 2>/dev/null) &
else
  exec 3</dev/input/event0
fi

EMU_DIR="/mnt/SDCARD/Emu"
LIST_FILE="/tmp/emusort_list.txt"

load_items() {
  jq -rn '[inputs | {d: (input_filename | split("/")[-2]), r: .label, c: (.label | gsub("^[\u0001-\u001f\ufeff\ufffe\u200b]+|^[0-9]{2}\\. "; ""))}] | sort_by(.r)[] | "\(.d)|\(.c)"' "$EMU_DIR"/*/config.json > "$LIST_FILE"
}

make_prefix() {
  idx_val="$1"
  n=$((idx_val - 1))
  out=""
  for b in 16 8 4 2 1; do
    if [ $(( (n / b) % 2 )) -eq 1 ]; then out="${out}\\ufffe"; else out="${out}\\ufeff"; fi
  done
  printf "%s\\ufeff" "$out"
}

load_items
TOTAL=$(wc -l < "$LIST_FILE" | tr -d " ")
if [ "$TOTAL" -eq 0 ]; then
  mv /dev/input/emusort_ev0 /dev/input/event0 2>/dev/null
  killall -9 st 2>/dev/null
  exit 0
fi

set -- $(stty size 2>/dev/null)
ROWS=${1:-29}; COLS=${2:-53}
PAGE_SIZE=$((ROWS - 6))
[ "$PAGE_SIZE" -lt 12 ] && PAGE_SIZE=18
[ "$PAGE_SIZE" -gt 20 ] && PAGE_SIZE=20
INNER_W=$((COLS - 4))
NAME_W=$((INNER_W - 18))

C_TL=$(printf "\342\224\214"); C_TR=$(printf "\342\224\220")
C_BL=$(printf "\342\224\224"); C_BR=$(printf "\342\224\230")
C_V=$(printf "\342\224\202");  C_H=$(printf "\342\224\200")
H_LINE=""; i=0; while [ "$i" -lt "$INNER_W" ]; do H_LINE="${H_LINE}${C_H}"; i=$((i + 1)); done
M_LINE=""; i=0; while [ "$i" -lt 39 ]; do M_LINE="${M_LINE}${C_H}"; i=$((i + 1)); done

CUR=1; GRAB=0
printf "\033[?25l\033[48;5;234m\033[2J"
stty -echo -icanon 2>/dev/null

quit_app() {
  mv /dev/input/emusort_ev0 /dev/input/event0 2>/dev/null
  stty sane 2>/dev/null
  printf "\033[?25h\033[0m"
  rm -f "$LIST_FILE" "$LIST_FILE.tmp"
  killall -9 st 2>/dev/null
  exit 0
}
trap quit_app INT TERM

swap_lines() {
  awk -v a="$1" -v b="$2" '{ l[NR]=$0 } END { t=l[a]; l[a]=l[b]; l[b]=t; for(i=1;i<=NR;i++) print l[i] }' "$LIST_FILE" > "$LIST_FILE.tmp" && mv "$LIST_FILE.tmp" "$LIST_FILE"
}

draw_modal() {
  msg="$1"
  r_mid=$((ROWS / 2 - 1))
  printf "\033[%d;7H\033[48;5;24m\033[1;37m%s%s%s\033[0m" "$r_mid" "$C_TL" "$M_LINE" "$C_TR"
  printf "\033[%d;7H\033[48;5;24m\033[1;33m%s  %-35.35s  %s\033[0m" "$((r_mid + 1))" "$C_V" "$msg" "$C_V"
  printf "\033[%d;7H\033[48;5;24m\033[1;37m%s%s%s\033[0m" "$((r_mid + 2))" "$C_BL" "$M_LINE" "$C_BR"
}

draw_ui() {
  START=$((CUR - PAGE_SIZE / 2))
  [ "$START" -lt 1 ] && START=1
  END=$((START + PAGE_SIZE - 1))
  if [ "$END" -gt "$TOTAL" ]; then END="$TOTAL"; START=$((END - PAGE_SIZE + 1)); [ "$START" -lt 1 ] && START=1; fi
  TITLE_PAD=$((COLS - 12))
  printf "\033[1;1H\033[48;5;24m\033[1;37m  %-*s\033[1;33m[%02d/%02d]  \033[0m\033[K" "$TITLE_PAD" "EMUSORT - CONSOLE MANAGER" "$CUR" "$TOTAL"
  printf "\033[2;1H\033[48;5;234m\033[38;5;67m %s%s%s \033[0m\033[K" "$C_TL" "$H_LINE" "$C_TR"
  idx=1; shown=0
  while IFS="|" read -r dir clean; do
    if [ "$idx" -ge "$START" ] && [ "$idx" -le "$END" ]; then
      row=$((3 + shown))
      if [ "$idx" -eq "$CUR" ]; then
        if [ "$GRAB" -eq 1 ]; then
          printf "\033[%d;1H\033[48;5;234m\033[38;5;67m %s\033[48;5;214m\033[1;30m >> %02d. %-*.*s [MOVING] \033[48;5;234m\033[38;5;67m%s \033[0m\033[K" "$row" "$C_V" "$idx" "$NAME_W" "$NAME_W" "$clean" "$C_V"
        else
          printf "\033[%d;1H\033[48;5;234m\033[38;5;67m %s\033[48;5;31m\033[1;37m  > %02d. %-*.*s [SELECT] \033[48;5;234m\033[38;5;67m%s \033[0m\033[K" "$row" "$C_V" "$idx" "$NAME_W" "$NAME_W" "$clean" "$C_V"
        fi
      else
        if [ $((shown % 2)) -eq 0 ]; then BG="235"; else BG="236"; fi
        printf "\033[%d;1H\033[48;5;234m\033[38;5;67m %s\033[48;5;%sm\033[38;5;245m    %02d. \033[1;37m%-*.*s\033[38;5;242m %8.8s \033[48;5;234m\033[38;5;67m%s \033[0m\033[K" "$row" "$C_V" "$BG" "$idx" "$NAME_W" "$NAME_W" "$clean" "[$dir]" "$C_V"
      fi
      shown=$((shown + 1))
    fi
    idx=$((idx + 1))
  done < "$LIST_FILE"
  while [ "$shown" -lt "$PAGE_SIZE" ]; do
    row=$((3 + shown))
    printf "\033[%d;1H\033[48;5;234m\033[38;5;67m %s\033[48;5;235m%*s\033[48;5;234m\033[38;5;67m%s \033[0m\033[K" "$row" "$C_V" "$INNER_W" "" "$C_V"
    shown=$((shown + 1))
  done
  r_bot=$((3 + PAGE_SIZE))
  printf "\033[%d;1H\033[48;5;234m\033[38;5;67m %s%s%s \033[0m\033[K" "$r_bot" "$C_BL" "$H_LINE" "$C_BR"
  printf "\033[%d;1H\033[48;5;234m  \033[48;5;28m\033[1;37m A \033[48;5;234m\033[0;37m Grab/Drop   \033[48;5;130m\033[1;37m B \033[48;5;234m\033[0;37m Cancel   \033[48;5;125m\033[1;37m X \033[48;5;234m\033[0;37m Reset A-Z\033[K" "$((r_bot + 1))"
  printf "\033[%d;1H\033[48;5;234m  \033[48;5;25m\033[1;37m START \033[48;5;234m\033[0;37m Save & Apply      \033[48;5;124m\033[1;37m MENU \033[48;5;234m\033[0;37m Exit App\033[K\033[0m" "$((r_bot + 2))"
}

save_items() {
  draw_modal "SAVING CONSOLE ORDER, PLEASE WAIT..."
  idx=1
  while IFS="|" read -r dir clean; do
    [ -z "$dir" ] && continue
    cfg="$EMU_DIR/$dir/config.json"
    [ -f "$cfg" ] || continue
    p=$(make_prefix "$idx")
    jq --arg c "$clean" --argjson p "\"$p\"" '.label = ($p + $c)' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
    idx=$((idx + 1))
  done < "$LIST_FILE"
  rm -f "$EMU_DIR"/*/*_cache6.db "$EMU_DIR"/*/*_cache7.db
  sync
}

reset_default() {
  draw_modal "RESETTING TO DEFAULT A-Z..."
  for cfg in "$EMU_DIR"/*/config.json; do
    [ -f "$cfg" ] || continue
    jq '.label |= gsub("^[\u0001-\u001f\ufeff\ufffe\u200b]+|^[0-9]{2}\\. "; "")' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
  done
  rm -f "$EMU_DIR"/*/*_cache6.db "$EMU_DIR"/*/*_cache7.db
  sync
  load_items
}

MENU_PRESSED=0
while true; do
  draw_ui
  while true; do
    set -- $(dd bs=16 count=1 <&3 2>/dev/null | od -d | head -n 1)
    [ -z "$6" ] && continue
    if [ "$6" -eq 1 ]; then
      if [ "$7" -eq 1 ] || [ "$7" -eq 102 ] || [ "$7" -eq 125 ] || [ "$7" -eq 139 ]; then
        if [ "$8" -eq 1 ]; then MENU_PRESSED=1
        elif [ "$8" -eq 0 ] && [ "$MENU_PRESSED" -eq 1 ]; then quit_app; fi
        continue
      fi
      if [ "$7" -eq 116 ]; then MENU_PRESSED=0; break; fi
      if [ "$8" -eq 1 ] || [ "$8" -eq 2 ]; then
        MENU_PRESSED=0
        if [ "$7" -eq 103 ]; then
          [ "$CUR" -gt 1 ] && { NEXT=$((CUR - 1)); [ "$GRAB" -eq 1 ] && swap_lines "$CUR" "$NEXT"; CUR="$NEXT"; }
          break
        elif [ "$7" -eq 108 ]; then
          [ "$CUR" -lt "$TOTAL" ] && { NEXT=$((CUR + 1)); [ "$GRAB" -eq 1 ] && swap_lines "$CUR" "$NEXT"; CUR="$NEXT"; }
          break
        fi
      fi
      if [ "$8" -eq 1 ]; then
        MENU_PRESSED=0
        if [ "$7" -eq 57 ]; then if [ "$GRAB" -eq 0 ]; then GRAB=1; else GRAB=0; fi; break
        elif [ "$7" -eq 29 ]; then if [ "$GRAB" -eq 1 ]; then GRAB=0; break; fi
        elif [ "$7" -eq 42 ]; then GRAB=0; reset_default; CUR=1; break
        elif [ "$7" -eq 28 ]; then save_items; quit_app
        fi
      fi
    fi
  done
done
