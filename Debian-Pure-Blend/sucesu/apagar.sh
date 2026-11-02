#!/bin/sh
. /cdrom/sucesu/comum.sh
travar

say "=== APAGAR DISCOS === console=$TTY dryrun=$DRYRUN"
limpa; tela "\n  SUCESU - preparando o apagamento...\n"

achar_midia
aguardar_discos
[ -n "$DISCOS" ] || abortar "nenhum disco interno encontrado (drivers ainda nao carregados?)"
cab_maquina
lista_discos_txt

# Simulacao: so mostra o que seria apagado
if [ "$DRYRUN" = 1 ]; then
  fim "\n  [SIMULACAO] Nada sera escrito.\n\n$CAB\n  Discos que seriam apagados:\n\n$LD\n"
fi

# Confirmacao obrigatoria: sem digitar SIM nada e apagado
limpa
tela "\n  =======================================================\n     SUCESU - APAGAR DISCOS\n  =======================================================\n\n$CAB\n  ESTES DISCOS SERAO APAGADOS (todos os dados, sem volta):\n\n$LD\n  Para confirmar, digite SIM e pressione ENTER.\n  Para cancelar, desligue a maquina.\n\n  > "
ler_linha
if [ "$LINHA" != "SIM" ]; then
  say "Cancelado pelo operador"
  fim "\n  Cancelado. NADA foi apagado.\n\n  Pressione ENTER para desligar.\n"
fi

# Inicia o apagamento de todos os discos em paralelo
LIST=""
for n in $DISCOS; do
  size=$(cat "/sys/block/$n/size")
  say "APAGANDO /dev/$n"
  dd if=/dev/zero of="/dev/$n" bs=4M conv=fsync >> "$LOG" 2>&1 &
  LIST="$LIST $n:$!:$((size * 512))"
done

# Tela de progresso (atualiza a cada 5 s)
INICIO=$(date +%s)
while :; do
  ativo=0
  now=$(date +%s); el=$(( now - INICIO ))
  scr='\033[H\033[2J'
  scr="$scr\n  SUCESU - APAGAMENTO EM ANDAMENTO (nao desligue a maquina)\n\n$CAB\n"
  scr="$scr  Decorrido: $(( el / 60 )) min\n\n"
  for item in $LIST; do
    n=${item%%:*}; rest=${item#*:}; pid=${rest%%:*}; total=${rest#*:}
    disco_desc "$n"
    if vivo "$pid"; then
      ativo=1
      if [ -r "/proc/$pid/io" ]; then
        wr=$(grep '^wchar' "/proc/$pid/io" 2>/dev/null | cut -d' ' -f2)
        pct=$(( ${wr:-0} / (total / 100 + 1) ))
        [ "$pct" -gt 100 ] && pct=100
        extra=""
        [ "$pct" -gt 0 ] && extra="  falta ~$(( el * (100 - pct) / pct / 60 )) min"
        scr="$scr  /dev/$n ($D_GIB GiB $D_TIPO)\n  $(barra $pct)$extra\n\n"
      else
        scr="$scr  /dev/$n ($D_GIB GiB $D_TIPO)  em andamento (sem percentual neste kernel)\n\n"
      fi
    else
      scr="$scr  /dev/$n ($D_GIB GiB $D_TIPO)\n  $(barra 100)  gravacao concluida\n\n"
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

# Verifica amostras e pede ao kernel para reler as tabelas de particao
FALHA=0; RESUMO=""
for item in $LIST; do
  n=${item%%:*}
  disco_desc "$n"
  verifica "$n"
  case "$VER_STATUS" in
    ok)    RESUMO="$RESUMO  /dev/$n  $D_GIB GiB  VERIFICADO (amostras zeradas)\n" ;;
    dados) RESUMO="$RESUMO  /dev/$n  $D_GIB GiB  FALHA: ha dados nao zerados\n"; FALHA=1 ;;
    *)     RESUMO="$RESUMO  /dev/$n  $D_GIB GiB  apagado (verificacao indisponivel)\n" ;;
  esac
  say "$n: $VER_STATUS"
  command -v blockdev >/dev/null 2>&1 && blockdev --rereadpt "/dev/$n" 2>/dev/null
done

if [ "$FALHA" = 1 ]; then
  say "RESULTADO: FALHA"
  fim "\n  =================================================\n     SUCESU: FALHA NO APAGAMENTO\n  =================================================\n\n$CAB\n$RESUMO\n  NAO use esta maquina. Pressione ENTER para desligar.\n"
fi

say "RESULTADO: OK"
fim "\n  =================================================\n     SUCESU: APAGAMENTO CONCLUIDO - OK\n  =================================================\n\n$CAB\n$RESUMO\n  Para conferir depois: menu 'VERIFICAR DISCOS'.\n  Pressione ENTER para DESLIGAR.\n"
