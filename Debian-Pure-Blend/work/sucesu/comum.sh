# Funcoes comuns do Sucesu (carregado com: . /cdrom/sucesu/comum.sh)
LOG=/var/log/sucesu.log
DRYRUN=0
grep -q sucesu_dryrun /proc/cmdline 2>/dev/null && DRYRUN=1

# Console: o instalador em modo texto usa o console atual (normalmente tty1)
ATIVO=$(cat /sys/class/tty/tty0/active 2>/dev/null)
case "$ATIVO" in
  tty[1-6]) ;;
  *) ATIVO=tty1; command -v chvt >/dev/null 2>&1 && chvt 1 2>/dev/null ;;
esac
TTY=/dev/$ATIVO
command -v stty >/dev/null 2>&1 && stty sane < "$TTY" 2>/dev/null

say()   { echo "[sucesu] $*" >> "$LOG"; logger -t sucesu "$*" 2>/dev/null; }
tela()  { { printf '%b' "$1" > "$TTY"; } 2>/dev/null; }
limpa() { tela '\033[H\033[2J'; }
trim()  { echo $*; }

# Garante execucao unica (o script e chamado por mais de um gancho)
travar() {
  [ -e /tmp/sucesu.lock ] && exit 0
  : > /tmp/sucesu.lock
}

# Le uma linha do console; fica esperando ate conseguir. Resultado em $LINHA (maiusculas)
ler_linha() {
  LINHA=""
  while :; do
    if read -r LINHA < "$TTY"; then break; fi
    sleep 2
  done
  LINHA=$(echo "$LINHA" | tr -d '\r' | tr 'a-z' 'A-Z')
}

desligar() {
  say "Desligando"
  sleep 2
  poweroff -f 2>/dev/null || halt -f 2>/dev/null || reboot -f
  exit 0
}

# Tela final: espera ENTER e desliga (em dryrun, so sai)
fim() {
  limpa; tela "$1"
  { printf '\a\a' > "$TTY"; } 2>/dev/null
  [ "$DRYRUN" = 1 ] && exit 0
  ler_linha
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

# ---- Informacoes da maquina ----
lerdmi() { cat "/sys/class/dmi/id/$1" 2>/dev/null; }

cab_maquina() {
  M_FAB=$(trim "$(lerdmi sys_vendor)"); M_MOD=$(trim "$(lerdmi product_name)")
  if [ -z "$M_MOD" ]; then
    M_FAB=$(trim "$(lerdmi board_vendor)"); M_MOD=$(trim "$(lerdmi board_name)")
  fi
  M_SER=$(trim "$(lerdmi product_serial)")
  [ -n "$M_SER" ] || M_SER=$(trim "$(lerdmi board_serial)")
  CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2); CPU=$(trim "$CPU")
  NUC=$(grep -c '^processor' /proc/cpuinfo)
  kb=$(grep -m1 MemTotal /proc/meminfo | tr -s ' ' | cut -d' ' -f2)
  r10=$(( ${kb:-0} * 10 / 1048576 ))
  RAM="$((r10 / 10)).$((r10 % 10)) GB"
  if [ -d /sys/firmware/efi ]; then BOOT=UEFI; else BOOT=BIOS; fi
  CAB="  Maquina : $M_FAB $M_MOD   S/N: ${M_SER:-?}\n  CPU     : $CPU ($NUC nucleos)\n  Memoria : $RAM   |  Boot: $BOOT\n"
  say "Maquina: $M_FAB $M_MOD S/N ${M_SER:-?} | CPU: $CPU ($NUC) | RAM: $RAM | $BOOT"
}

# Define D_GIB, D_GB, D_TIPO, D_MOD para o disco $1
disco_desc() {
  n=$1
  setores=$(cat "/sys/block/$n/size")
  D_GIB=$(( setores / 2097152 ))
  D_GB=$(( setores / 1953125 ))
  if [ "$(cat "/sys/block/$n/queue/rotational" 2>/dev/null)" = "1" ]; then D_TIPO=HDD; else D_TIPO="SSD/NVMe"; fi
  v=$(trim "$(cat "/sys/block/$n/device/vendor" 2>/dev/null)")
  m=$(trim "$(cat "/sys/block/$n/device/model" 2>/dev/null)")
  D_MOD=$(trim "$v $m")
}

# Monta LD com a lista de discos (tamanho, tipo, modelo)
lista_discos_txt() {
  LD=""
  for n in $DISCOS; do
    disco_desc "$n"
    LD="$LD  /dev/$n   $D_GIB GiB ($D_GB GB)   $D_TIPO   $D_MOD\n"
    say "Disco /dev/$n: $D_GIB GiB ($D_GB GB) $D_TIPO $D_MOD"
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
