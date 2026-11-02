#!/bin/sh
. /cdrom/sucesu/comum.sh

# Força o TTY para o principal visível no boot se o TTY 6 falhar
TTY=/dev/tty1
exec >/var/log/sucesu-apagar.log 2>&1

say "=== APAGAR DISCOS === dryrun=$DRYRUN"
limpa; tela "\n\033[1;31m  SUCESU - PREPARANDO O APAGAMENTO SEGURO DOS DISCOS...\033[0m\n\n"

achar_midia
aguardar_discos
[ -n "$DISCOS" ] || abortar "Nenhum disco interno encontrado!"

LIST=""; RESUMO=""
for n in $DISCOS; do
  size=$(cat "/sys/block/$n/size")
  gib=$((size / 2097152))
  if [ "$(cat "/sys/block/$n/queue/rotational" 2>/dev/null)" = "1" ]; then tipo=HDD; else tipo="SSD/NVMe"; fi

  say "APAGANDO /dev/$n ($gib GiB, $tipo)"
  # Executa o dd mostrando progresso visível
  dd if=/dev/zero of="/dev/$n" bs=4M conv=fsync status=progress >> "$LOG" 2>&1 &
  LIST="$LIST $n:$!:$((size * 512))"
done

# Tela de progresso interativa atualizada a cada 3 segundos
INICIO=$(date +%s)
while :; do
  ativo=0
  now=$(date +%s); el=$(( now - INICIO ))
  scr='\033[H\033[2J'
  scr="$scr\n  \033[1;33mSUCESU - APAGAMENTO SEGURO DE DISCOS (NAO DESLIGUE A MAQUINA)\033[0m\n"
  scr="$scr  Tempo decorrido: $(( el / 60 )) min\n\n"
  for item in $LIST; do
    n=${item%%:*}; rest=${item#*:}; pid=${rest%%:*}; total=${rest#*:}
    if vivo "$pid"; then
      ativo=1
      if [ -r "/proc/$pid/io" ]; then
        wr=$(grep '^wchar' "/proc/$pid/io" 2>/dev/null | cut -d' ' -f2)
        pct=$(( ${wr:-0} / (total / 100 + 1) ))
        [ "$pct" -gt 100 ] && pct=100
        scr="$scr  /dev/$n -> $(barra $pct)\n"
      else
        scr="$scr  /dev/$n -> em andamento...\n"
      fi
    else
      scr="$scr  /dev/$n -> $(barra 100) [CONCLUIDO]\n"
    fi
  done
  tela "$scr"
  [ "$ativo" = 0 ] && break
  sleep 3
done

# Finalização e verificação igual ao seu script original...
