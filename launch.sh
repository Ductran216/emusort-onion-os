#!/bin/sh
export PATH="/mnt/SDCARD/.tmp_update/bin:/bin:/sbin:/usr/bin:/usr/sbin:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/.tmp_update/lib:/lib:/usr/lib:$LD_LIBRARY_PATH"
if [ "$1" != "--tui" ]; then
  /mnt/SDCARD/.tmp_update/bin/st -q -e /bin/sh "$0" --tui 2>/dev/null || /mnt/SDCARD/.tmp_update/bin/st -e /bin/sh "$0" --tui
  exit 0
fi
(usleep 150000 2>/dev/null || sleep 1; printf "\0\0\0\0\0\0\0\0\001\0\141\0\001\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" > /dev/input/event0 2>/dev/null; usleep 40000 2>/dev/null; printf "\0\0\0\0\0\0\0\0\001\0\141\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" > /dev/input/event0 2>/dev/null) &
EMU_DIR="/mnt/SDCARD/Emu"
LIST_FILE="/tmp/emusort_list.txt"
load_items() {
  jq -rn '[inputs | {d: (input_filename | split("/")[-2]), r: .label, c: (.label | gsub("^[\u0001-\u001f\ufeff\ufffe\u200b]+|^[0-9]{2}\\. "; ""))}] | sort_by(.r)[] | "\(.d)|\(.c)"' "$EMU_DIR"/*/config.json > "$LIST_FILE"
}
make_prefix() {
  n=$(($1 - 1)); out=""
  for b in 16 8 4 2 1; do
    if [ $(( (n / b) % 2 )) -eq 1 ]; then out="${out}\\ufffe"; else out="${out}\\ufeff"; fi
  done
  printf "%s\\ufeff" "$out"
}
save_items() {
  printf "\033[2J\033[H\n  \033[1;33mSaving console order...\033[0m\n"
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
  printf "\033[2J\033[H\n  \033[1;33mResetting to default A-Z...\033[0m\n"
  for cfg in "$EMU_DIR"/*/config.json; do
    [ -f "$cfg" ] || continue
    jq '.label |= gsub("^[\u0001-\u001f\ufeff\ufffe\u200b]+|^[0-9]{2}\\. "; "")' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
  done
  rm -f "$EMU_DIR"/*/*_cache6.db "$EMU_DIR"/*/*_cache7.db
  sync
  load_items
}
load_items
TOTAL=$(wc -l < "$LIST_FILE" | tr -d " ")
if [ "$TOTAL" -eq 0 ]; then killall -9 st 2>/dev/null; exit 0; fi
set -- $(stty size 2>/dev/null)
ROWS=${1:-29}; COLS=${2:-53}
PAGE_SIZE=$((ROWS - 7)); [ "$PAGE_SIZE" -lt 10 ] && PAGE_SIZE=18
NAME_W=$((COLS - 14)); [ "$NAME_W" -lt 20 ] && NAME_W=38
SEP_EQ=$(printf "%*s" "$COLS" "" | tr " " "=")
SEP_DA=$(printf "%*s" "$COLS" "" | tr " " "-")
CUR=1; GRAB=0
printf "\033[?25l\033[2J"
stty -echo -icanon 2>/dev/null
quit_app() {
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
exec 3</dev/input/event0
while true; do
  START=$((CUR - PAGE_SIZE / 2))
  [ "$START" -lt 1 ] && START=1
  END=$((START + PAGE_SIZE - 1))
  if [ "$END" -gt "$TOTAL" ]; then END="$TOTAL"; START=$((END - PAGE_SIZE + 1)); [ "$START" -lt 1 ] && START=1; fi
  TITLE_W=$((COLS - 10))
  printf "\033[H\033[1;36m%s\033[0m\n" "$SEP_EQ"
  printf " \033[1;37m%-*s\033[1;33m(%02d/%02d)\033[0m\n" "$TITLE_W" "EMUSORT - CONSOLE ORDER MANAGER" "$CUR" "$TOTAL"
  printf "\033[1;36m%s\033[0m\n" "$SEP_EQ"
  idx=1; shown=0
  while IFS="|" read -r dir clean; do
    if [ "$idx" -ge "$START" ] && [ "$idx" -le "$END" ]; then
      if [ "$idx" -eq "$CUR" ]; then
        if [ "$GRAB" -eq 1 ]; then printf " \033[1;33;44m [MOVE] %02d. %-*.*s \033[0m\033[K\n" "$idx" "$NAME_W" "$NAME_W" "$clean"
        else printf " \033[1;30;42m   >>   %02d. %-*.*s \033[0m\033[K\n" "$idx" "$NAME_W" "$NAME_W" "$clean"; fi
      else printf "         %02d. %-*.*s \033[K\n" "$idx" "$NAME_W" "$NAME_W" "$clean"; fi
      shown=$((shown + 1))
    fi
    idx=$((idx + 1))
  done < "$LIST_FILE"
  while [ "$shown" -lt "$PAGE_SIZE" ]; do printf "\033[K\n"; shown=$((shown + 1)); done
  printf "\033[1;36m%s\033[0m\n" "$SEP_DA"
  printf " \033[1;32mA\033[0m: Grab/Drop   \033[1;33mB\033[0m: Cancel   \033[1;35mX\033[0m: Reset A-Z\033[K\n"
  printf " \033[1;36mSTART\033[0m: Save & Apply        \033[1;31mMENU\033[0m: Exit App\033[K"
  while true; do
    set -- $(dd bs=16 count=1 <&3 2>/dev/null | od -d | head -n 1)
    [ -z "$6" ] && continue
    if [ "$6" -eq 1 ]; then
      if [ "$8" -eq 1 ] || [ "$8" -eq 2 ]; then
        if [ "$7" -eq 103 ]; then
          [ "$CUR" -gt 1 ] && { NEXT=$((CUR - 1)); [ "$GRAB" -eq 1 ] && swap_lines "$CUR" "$NEXT"; CUR="$NEXT"; }
          break
        elif [ "$7" -eq 108 ]; then
          [ "$CUR" -lt "$TOTAL" ] && { NEXT=$((CUR + 1)); [ "$GRAB" -eq 1 ] && swap_lines "$CUR" "$NEXT"; CUR="$NEXT"; }
          break
        fi
      fi
      if [ "$8" -eq 1 ]; then
        if [ "$7" -eq 1 ] || [ "$7" -eq 102 ] || [ "$7" -eq 125 ] || [ "$7" -eq 139 ]; then quit_app
        elif [ "$7" -eq 57 ]; then if [ "$GRAB" -eq 0 ]; then GRAB=1; else GRAB=0; fi; break
        elif [ "$7" -eq 29 ]; then if [ "$GRAB" -eq 1 ]; then GRAB=0; break; fi
        elif [ "$7" -eq 42 ]; then GRAB=0; reset_default; CUR=1; break
        elif [ "$7" -eq 28 ]; then save_items; quit_app
        fi
      fi
    fi
  done
done
