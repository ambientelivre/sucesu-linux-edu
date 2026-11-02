#!/bin/sh
. /cdrom/sucesu/comum.sh

say "=== VERIFICAR DISCOS ==="
vt_ir
limpa; tela "\n  SUCESU - verificando discos (somente leitura)...\n"

achar_midia
aguardar_discos
[ -n "$DISCOS" ] || abortar "nenhum disco interno encontrado"

RESUMO=""; PROB=0
for n in $DISCOS; do
  gib=$(( $(cat "/sys/block/$n/size") / 2097152 ))
  verifica "$n"
  case "$VER_STATUS" in
    ok)    RESUMO="$RESUMO  /dev/$n  $gib GiB  ZERADO (amostras)\n" ;;
    dados) RESUMO="$RESUMO  /dev/$n  $gib GiB  CONTEM DADOS - nao esta apagado\n"; PROB=1 ;;
    *)     RESUMO="$RESUMO  /dev/$n  $gib GiB  verificacao indisponivel\n" ;;
  esac
  say "$n: $VER_STATUS"
done

if [ "$PROB" = 1 ]; then
  fim "\n  =================================================\n     SUCESU: EXISTEM DISCOS COM DADOS\n  =================================================\n\n$RESUMO\n  Pressione ENTER para desligar.\n"
fi
fim "\n  =================================================\n     SUCESU: DISCOS CONFERIDOS - OK\n  =================================================\n\n$RESUMO\n  Pressione ENTER para desligar.\n"
