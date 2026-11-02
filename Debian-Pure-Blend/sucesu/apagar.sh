#!/bin/sh
. /cdrom/sucesu/comum.sh

say "=== APAGAR DISCOS === dryrun=$DRYRUN"
vt_ir
limpa; tela "\n  SUCESU - preparando o apagamento...\n"

achar_midia
aguardar_discos
[ -n "$DISCOS" ] || abortar "nenhum disco interno encontrado (drivers ainda nao carregados?)"

LIST=""; RESUMO=""
for n in $DISCOS; do
  size=$(cat "/sys/block/$n/size")
  gib=$((size / 2097152))
  if [ "$(cat "/sys/block/$n/queue/rotational" 2>/dev/null)" = "1" ]; then tipo=HDD; else tipo="SSD/NVMe"; fi

  if [ "$DRYRUN" = 1 ]; then
    say "[DRYRUN] apagaria /dev/$n ($gib GiB, $tipo)"
    RESUMO="$RESUMO  /dev/$n  $gib GiB  $tipo\n"
    continue
  fi

  say "APAGANDO /dev/$n ($gib GiB, $tipo)"
  [ "$tipo" = "SSD/NVMe" ] && say "AVISO: zerar SSD nao garante apagar areas reservadas do controlador."
  dd if=/dev/zero of="/dev/$n" bs=4M conv=fsync >> "$LOG" 2>&1 &
  LIST="$LIST $n:$!:$((size * 512))"
done

[ "$DRYRUN" = 1 ] && fim "\n  [SIMULACAO] Nada foi escrito. Discos que seriam apagados:\n\n$RESUMO\n"

# Progresso (atualiza a cada 5 s)
INICIO=$(date +%s)
while :; do
  ativo=0
  now=$(date +%s); el=$(( now - INICIO ))
  scr='\033[H\033[2J'
  scr="$scr\n  SUCESU - APAGAMENTO DE DISCOS (nao desligue a maquina)\n"
  scr="$scr  Decorrido: $(( el / 60 )) min\n\n"
  for item in $LIST; do
    n=${item%%:*}; rest=${item#*:}; pid=${rest%%:*}; total=${rest#*:}
    if vivo "$pid"; then
      ativo=1
      if [ -r "/proc/$pid/io" ]; then
        wr=$(grep '^wchar' "/proc/$pid/io" 2>/dev/null | cut -d' ' -f2)
        pct=$(( ${wr:-0} / (total / 100 + 1) ))
        [ "$pct" -gt 100 ] && pct=100
        extra=""
        [ "$pct" -gt 0 ] && extra="  falta ~$(( el * (100 - pct) / pct / 60 )) min"
        scr="$scr  /dev/$n  $(barra $pct)$extra\n"
      else
        scr="$scr  /dev/$n  em andamento (sem percentual neste kernel)\n"
      fi
    else
      scr="$scr  /dev/$n  $(barra 100)  gravacao concluida\n"
    fi
  done
  tela "$scr"
  [ "$ativo" = 0 ] && break
  sleep 5
done

for item in $LIST; do
  rest=${item#*:}; pid=${rest%%:*}
  wait "$pid" 2>/dev/null
  say "dd de ${item%%:*} terminou (codigo $?; 'No space left' e esperado)"
done
say "Gravacao concluida em $(( ($(date +%s) - INICIO) / 60 )) min. Verificando..."
tela '\n  Verificando amostras dos discos...\n'

FALHA=0; RESUMO=""
for item in $LIST; do
  n=${item%%:*}
  gib=$(( $(cat "/sys/block/$n/size") / 2097152 ))
  verifica "$n"
  case "$VER_STATUS" in
    ok)    RESUMO="$RESUMO  /dev/$n  $gib GiB  VERIFICADO (amostras zeradas)\n" ;;
    dados) RESUMO="$RESUMO  /dev/$n  $gib GiB  FALHA: ha dados nao zerados\n"; FALHA=1 ;;
    *)     RESUMO="$RESUMO  /dev/$n  $gib GiB  apagado (verificacao indisponivel)\n" ;;
  esac
  say "$n: $VER_STATUS"
done

if [ "$FALHA" = 1 ]; then
  say "RESULTADO: FALHA"
  fim "\n  =================================================\n     SUCESU: FALHA NO APAGAMENTO\n  =================================================\n\n$RESUMO\n  NAO use esta maquina. Pressione ENTER para desligar.\n"
fi

say "RESULTADO: OK"
fim "\n  =================================================\n     SUCESU: APAGAMENTO CONCLUIDO - OK\n  =================================================\n\n$RESUMO\n  Para conferir depois: menu 'VERIFICAR DISCOS'.\n  Pressione ENTER para DESLIGAR.\n"
