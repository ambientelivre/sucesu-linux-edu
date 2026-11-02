#!/bin/sh
# Define o wallpaper e a posicao da caixa da tela de login (LightDM). Roda dentro do sistema instalado.
F=/etc/lightdm/lightdm-gtk-greeter.conf
IMG=/usr/share/backgrounds/sucesu.jpg
[ -f "$IMG" ] || exit 0
mkdir -p /etc/lightdm
[ -f "$F" ] || echo '[greeter]' > "$F"
grep -q '^\[greeter\]' "$F" || echo '[greeter]' >> "$F"
sed -i -e '/^#\?background=/d' -e '/^#\?user-background=/d' -e '/^#\?position=/d' "$F"
sed -i "/^\[greeter\]/a background=$IMG\nuser-background=false\nposition=18%,center 21%,center" "$F"
exit 0


#!/bin/sh
# Define o wallpaper da tela de login (LightDM). Roda dentro do sistema instalado.
#F=/etc/lightdm/lightdm-gtk-greeter.conf
#IMG=/usr/share/backgrounds/sucesu.jpg
#[ -f "$IMG" ] || exit 0
#mkdir -p /etc/lightdm
#[ -f "$F" ] || echo '[greeter]' > "$F"
#grep -q '^\[greeter\]' "$F" || echo '[greeter]' >> "$F"
#sed -i -e '/^#\?background=/d' -e '/^#\?user-background=/d' "$F"
#sed -i "/^\[greeter\]/a background=$IMG\nuser-background=false" "$F"
#exit 0
