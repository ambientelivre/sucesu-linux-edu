# Funcoes comuns do Sucesu (carregado com: . /cdrom/sucesu/comum.sh)
LOG=/var/log/sucesu.log
VT=6
TTY=/dev/tty$VT
NOVT=0
ATIVO=""
DRYRUN=0
grep -q sucesu_dryrun /proc/cmdline 2>/dev/null && DRYRUN=1

say()   { echo "[sucesu] $*" >> "$LOG"; logger -t sucesu "$*" 2>/dev/null; }
tela()  { { printf '%b' "$1" > "$TTY"; } 2>/dev/null; }
limpa() { tela '\033[H\033[2J'; }

vt_ir() {
  ATIVO=$(cat /sys/class/tty/tty0/active 2>/dev/null); ATIVO=${ATIVO#tty}
  command -v chvt >/dev/null 2>&1 || return 0
  chvt "$VT" 2>/dev/null; sleep 1
  [ "$(cat /sys/class/tty/tty0/active 2>/dev/null)" = "tty$VT" ] && NOVT=1
  return 0
}

esperar_enter() {
  if [ "$NOVT" = 1 ]; then read dummy < "$TTY"; else sleep "${1:-60}"; fi
}

desligar() {
  say "Desligando"
  sleep 2
  poweroff -f 2>/dev/null || halt -f 2>/dev/null || reboot -f
  exit 0
}

# Mostra a tela final e desliga apos ENTER (em dryrun, so sai)
fim() {
  limpa; tela "$1"
  { printf '\a\a' > "$TTY"; } 2>/dev/null
  [ "$DRYRUN" = 1 ] && exit 0
  esperar_enter 120
  desligar
}

abortar() {
  say "ERRO: $1"
  fim "\n  SUCESU - ERRO: $1\n  NADA FOI ALTERADO.\n\n  Pressione ENTER para desligar.\n"
}

# Descobre o disco da midia de instalacao (nunca e tocado)
achar_midia() {
  dev=$(grep ' /cdrom ' /proc/mounts | head -n 1 | cut -d' ' -f1)
  [ -n "$dev" ] || abortar "midia de instalacao nao identificada em /cdrom"
  name=${dev#/dev/}
  real=$(readlink -f "/sys/class/block/$name" 2>/dev/null)
  [ -n "$real" ] || abortar "nao consegui resolver $dev em /sys"
  [ -e "/sys/class/block/$name/partition" ] && real=${real%/*}
  PARENT=${real##*/}
  [ -n "$PARENT" ] || abortar "disco pai de $dev nao identificado"
  say "Midia de instalacao: $dev (disco $PARENT) - preservada"
}

# Preenche DISCOS com os discos internos (sem a midia, removiveis e RO)
listar_discos() {
  DISCOS=""
  for d in /sys/block/*; do
    n=${d##*/}
    case "$n" in sd*|hd*|vd*|xvd*|nvme*) ;; *) continue ;; esac
    [ "$n" = "$PARENT" ] && continue
    [ "$(cat "$d/removable" 2>/dev/null)" = "1" ] && continue
    [ "$(cat "$d/ro" 2>/dev/null)" = "1" ] && continue
    size=$(cat "$d/size" 2>/dev/null)
    [ -n "$size" ] && [ "$size" -gt 0 ] || continue
    DISCOS="$DISCOS $n"
  done
}

# No inicio do instalador os drivers de disco podem demorar: espera ate 30 s
aguardar_discos() {
  t=0
  while :; do
    listar_discos
    [ -n "$DISCOS" ] && return 0
    [ "$t" -ge 30 ] && return 0
    command -v udevadm >/dev/null 2>&1 && udevadm settle 2>/dev/null
    sleep 3; t=$((t + 3))
  done
}

barra() {
  w=40; f=$(( $1 * w / 100 )); b=""; i=0
  while [ "$i" -lt "$w" ]; do
    if [ "$i" -lt "$f" ]; then b="$b#"; else b="$b-"; fi
    i=$((i + 1))
  done
  echo "[$b] $1%"
}

vivo() {
  [ -d "/proc/$1" ] || return 1
  grep -q '^State:[[:space:]]*Z' "/proc/$1/status" 2>/dev/null && return 1
  return 0
}

# Le 16 MiB do inicio e 33 amostras de 1 MiB espalhadas (incluindo o fim).
# Define VER_STATUS = ok | dados | indisp
verifica() {
  n=$1
  sz=$(( $(cat "/sys/block/$n/size") / 2048 ))
  VER_STATUS=ok
  [ "$sz" -gt 40 ] || return 0
  i=0
  while [ "$i" -le 32 ]; do
    pos=$(( sz * i / 33 )); cnt=1
    [ "$i" = 0 ] && cnt=16
    [ "$i" = 32 ] && pos=$((sz - 1))
    nz=$(dd if="/dev/$n" bs=1M skip="$pos" count="$cnt" 2>/dev/null | tr -d '\000' | wc -c)
    nz=$(echo $nz)
    case "$nz" in
      ''|*[!0-9]*) [ "$VER_STATUS" = ok ] && VER_STATUS=indisp ;;
      *) [ "$nz" -eq 0 ] || VER_STATUS=dados ;;
    esac
    i=$((i + 1))
  done
}
