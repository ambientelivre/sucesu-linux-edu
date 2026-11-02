#!/bin/sh
. /cdrom/sucesu/comum.sh
travar

say "=== VERIFICAR DISCOS === console=$TTY"
limpa; tela "\n  SUCESU - verificando discos (somente leitura)...\n"

achar_midia
aguardar_discos
[ -n "$DISCOS" ] || abortar "nenhum disco interno encontrado"
cab_maquina

RESUMO=""; PROB=0
for n in $DISCOS; do
  disco_desc "$n"
  tela "\n  Lendo /dev/$n ($D_GIB GiB)...\n"
  verifica "$n"
  case "$VER_STATUS" in
    ok)    RESUMO="$RESUMO  /dev/$n   $D_GIB GiB ($D_GB GB)  $D_TIPO  $D_MOD\n             -> ZERADO (amostras)\n" ;;
    dados) RESUMO="$RESUMO  /dev/$n   $D_GIB GiB ($D_GB GB)  $D_TIPO  $D_MOD\n             -> CONTEM DADOS - nao esta apagado\n"; PROB=1 ;;
    *)     RESUMO="$RESUMO  /dev/$n   $D_GIB GiB ($D_GB GB)  $D_TIPO  $D_MOD\n             -> verificacao indisponivel\n" ;;
  esac
  say "$n: $VER_STATUS"
done

if [ "$PROB" = 1 ]; then
  fim "\n  =================================================\n     SUCESU: EXISTEM DISCOS COM DADOS\n  =================================================\n\n$CAB\n$RESUMO\n  Pressione ENTER para desligar.\n"
fi
fim "\n  =================================================\n     SUCESU: DISCOS CONFERIDOS - OK\n  =================================================\n\n$CAB\n$RESUMO\n  Pressione ENTER para desligar.\n"
