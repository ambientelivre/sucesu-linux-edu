#!/bin/bash
set -euo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
ORIG="$(realpath -m "${1:-$BASE/debian-edu-13.7.0-amd64-netinst.iso}")"
NOME="$(basename "$ORIG" .iso)"
VERSAO="$(date +%Y.%m.%d)"
SAIDA="$BASE/sucesu-pr-$NOME-$VERSAO.iso"
WORK="$BASE/work"
# mantém o volume ID da ISO original (evita estourar o limite de 32 caracteres)
VOLID=$(xorriso -indev "$ORIG" -toc 2>&1 | sed -n "s/^Volume id *: '\(.*\)'.*/\1/p" | head -n1)
[ -n "$VOLID" ] || VOLID="Debian Edu 13.7.0"
EXTRA="debian-installer/locale=pt_BR.UTF-8 keyboard-configuration/xkb-keymap=br"

# 0) Pré-requisitos
[ -f "$ORIG" ] || { echo "ISO original não encontrada: $ORIG"; exit 1; }
for f in wallpaper.jpg wallpaper.sh login.sh comum.sh apagar.sh verificar.sh; do
  [ -f "$BASE/sucesu/$f" ] || { echo "Falta sucesu/$f"; exit 1; }
done
command -v xorriso >/dev/null || { echo "Instale: sudo apt install xorriso"; exit 1; }

rm -rf "$WORK"; mkdir -p "$WORK/sucesu" "$WORK/boot/grub" "$WORK/isolinux"

# 1) Arquivos que vão para a ISO
cp "$BASE"/sucesu/* "$WORK/sucesu/"

cat > "$WORK/sucesu/wallpaper.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Sucesu Wallpaper
Exec=/usr/local/bin/sucesu-wallpaper.sh
EOF

# Instalação normal (só wallpaper)
cat > "$WORK/sucesu/sucesu.cfg" <<'EOF'
d-i preseed/late_command string \
  mkdir -p /target/usr/share/backgrounds /target/etc/xdg/autostart /target/usr/local/bin; \
  cp /cdrom/sucesu/wallpaper.jpg /target/usr/share/backgrounds/sucesu.jpg; \
  cp /cdrom/sucesu/wallpaper.sh /target/usr/local/bin/sucesu-wallpaper.sh; \
  chmod +x /target/usr/local/bin/sucesu-wallpaper.sh; \
  cp /cdrom/sucesu/wallpaper.desktop /target/etc/xdg/autostart/sucesu-wallpaper.desktop; \
  cp /cdrom/sucesu/login.sh /target/tmp/sucesu-login.sh; \
  in-target sh /tmp/sucesu-login.sh; \
  rm -f /target/tmp/sucesu-login.sh
EOF

# Entradas só-apagar e só-verificar: rodam no início e não instalam nada
echo 'd-i preseed/early_command string sh /cdrom/sucesu/apagar.sh'    > "$WORK/sucesu/apagar.cfg"
echo 'd-i preseed/early_command string sh /cdrom/sucesu/verificar.sh' > "$WORK/sucesu/verificar.cfg"

# 2) Extrai só os menus de boot da ISO original
xorriso -osirrox on -indev "$ORIG" \
  -extract /boot/grub/grub.cfg "$WORK/boot/grub/grub.cfg" \
  -extract /isolinux "$WORK/isolinux" 2>/dev/null
chmod -R u+w "$WORK"

# 3) Segurança: não sobrescrever preseed que o Debian Edu já use
if grep -rqs "preseed/file=" "$WORK/boot/grub/grub.cfg" "$WORK"/isolinux/*.cfg; then
  echo "ATENÇÃO: o menu de boot já usa preseed/file. Linhas:"
  grep -rns "preseed/file=" "$WORK/boot/grub/grub.cfg" "$WORK"/isolinux/*.cfg
  echo "Não vou sobrescrever. Cole essa saída para ajustarmos (merge no preseed existente)."
  exit 2
fi

# 4) Injeta o preseed antes do ' ---' nas linhas de kernel
P="preseed\/file=\/cdrom\/sucesu\/sucesu.cfg"
sed -i -E "/^\s*linux\s.*vmlinuz/ s/ ---/ $P ---/" "$WORK/boot/grub/grub.cfg"
sed -i -E "/^\s*append\s.*initrd=/ s/ ---/ $P ---/" "$WORK"/isolinux/*.cfg

echo "Linhas alteradas:"
grep -rns "sucesu.cfg" "$WORK/boot/grub/grub.cfg" "$WORK"/isolinux/*.cfg || \
  { echo "Nenhuma linha alterada, formato dos menus diferente do esperado."; exit 3; }

# 4b) Novas entradas de menu (BIOS e UEFI), copiadas da "Graphical install" do Edu
GTK="$WORK/isolinux/gtk.cfg"
GRUB="$WORK/boot/grub/grub.cfg"
[ -f "$GTK" ] || { echo "isolinux/gtk.cfg não existe, não dá para criar as entradas BIOS."; exit 5; }

add_isolinux() {   # $1=label  $2=texto do menu  $3=arquivo cfg
  awk 'tolower($1)=="label"{n++} n==1' "$GTK" | sed -E \
    -e "s/^([[:space:]]*)[Ll][Aa][Bb][Ee][Ll][[:space:]].*/\1label $1/" \
    -e "s/^([[:space:]]*)menu label .*/\1menu label $2/I" \
    -e '/^[[:space:]]*menu default/Id' \
    -e "s#sucesu/sucesu\.cfg#sucesu/$3 $EXTRA#" \
    > "$WORK/blk-$1.tmp"
  grep -q "sucesu/$3" "$WORK/blk-$1.tmp" || \
    { echo "Entrada BIOS '$1' não aponta para $3. Abortando."; exit 5; }
  { printf '\n'; cat "$WORK/blk-$1.tmp"; } >> "$GTK"
}

add_grub() {       # $1=texto do menu  $2=arquivo cfg ; retorna 1 se não conseguiu
  awk '
    !found && /^[[:space:]]*menuentry .*[Gg]raphical install/ { found=1; cap=1 }
    cap { print }
    cap && /^[[:space:]]*}[[:space:]]*$/ { cap=0 }
  ' "$GRUB" | sed -E \
    -e "s/[Gg]raphical install/$1/" \
    -e 's/ --hotkey=[a-z]//' \
    -e "s#sucesu/sucesu\.cfg#sucesu/$2 $EXTRA#" \
    > "$WORK/blk-grub-$2.tmp"
  grep -q "sucesu/$2" "$WORK/blk-grub-$2.tmp" || return 1
  { printf '\n'; cat "$WORK/blk-grub-$2.tmp"; } >> "$GRUB"
}

T_APAGAR="Sucesu: APAGAR DISCOS (so apaga, NAO instala)"
T_VERIF="Sucesu: VERIFICAR DISCOS (so le, nao altera nada)"

add_isolinux sucesu-apagar   "$T_APAGAR" apagar.cfg
add_isolinux sucesu-verificar "$T_VERIF" verificar.cfg

if add_grub "$T_APAGAR" apagar.cfg && add_grub "$T_VERIF" verificar.cfg; then
  ENT_UEFI="SIM"
else
  ENT_UEFI="NAO"
  echo "!!! AVISO: entradas UEFI (grub) NÃO criadas. Formato do grub.cfg diferente do esperado."
  echo "!!! Cole o conteúdo de work/boot/grub/grub.cfg para ajustarmos."
fi

# 5) md5sum.txt atualizado
xorriso -osirrox on -indev "$ORIG" -extract /md5sum.txt "$WORK/md5sum.txt" 2>/dev/null
chmod u+w "$WORK/md5sum.txt"
( cd "$WORK" && for f in sucesu/* boot/grub/grub.cfg isolinux/*.cfg; do
    sed -i "\|  ./$f\$|d" md5sum.txt
    md5sum "$f" | sed 's|  |  ./|' >> md5sum.txt
  done )

# 6) Remonta preservando o boot original (BIOS e UEFI)
MAPS=()
for f in $(grep -lE "sucesu\.cfg|apagar\.cfg|verificar\.cfg" "$WORK"/isolinux/*.cfg); do
  MAPS+=(-map "$f" "/isolinux/$(basename "$f")")
done

rm -f "$SAIDA"
xorriso -indev "$ORIG" -outdev "$SAIDA" \
  -volid "$VOLID" \
  -map "$WORK/sucesu" /sucesu \
  -map "$WORK/boot/grub/grub.cfg" /boot/grub/grub.cfg \
  "${MAPS[@]}" \
  -map "$WORK/md5sum.txt" /md5sum.txt \
  -boot_image any replay \
  -commit || { rm -f "$SAIDA"; echo "Falhou, ISO removida."; exit 4; }

echo "Pronto: $SAIDA"
echo "Entradas APAGAR/VERIFICAR -> BIOS: SIM | UEFI: $ENT_UEFI"
