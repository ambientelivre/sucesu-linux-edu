#!/bin/sh
M="$HOME/.config/.sucesu-wallpaper-done"
IMG=/usr/share/backgrounds/sucesu.jpg
mkdir -p "$HOME/.cache" "$HOME/.config"
exec >>"$HOME/.cache/sucesu-wallpaper.log" 2>&1
echo "== $(date) desktop=${XDG_CURRENT_DESKTOP:-?} sessao=${XDG_SESSION_TYPE:-?}"
[ -f "$M" ] && { echo "ja aplicado"; exit 0; }
[ -f "$IMG" ] || { echo "imagem ausente"; exit 0; }

espera() {   # espera um processo do usuario por ate 60 s
  i=0
  while [ "$i" -lt 60 ]; do
    pgrep -u "$(id -u)" -x "$1" >/dev/null && return 0
    sleep 1; i=$((i + 1))
  done
  return 1
}

case "${XDG_CURRENT_DESKTOP:-}" in
  *KDE*)
    espera plasmashell || { echo "plasmashell nao iniciou"; exit 0; }
    sleep 3
    plasma-apply-wallpaperimage "$IMG" && touch "$M"
    ;;
  *XFCE*|*Xfce*)
    espera xfdesktop || { echo "xfdesktop nao iniciou"; exit 0; }
    sleep 3
    # formato antigo (monitor0, monitor1...), inofensivo se nao for usado
    for p in $(xfconf-query -c xfce4-desktop -l | grep '/last-image$'); do
      xfconf-query -c xfce4-desktop -p "$p" -s "$IMG"
    done
    # formato atual: monitor<nome do xrandr>/workspaceN (confirmado no seu teste)
    ok=0
    for m in $(xrandr --listmonitors 2>/dev/null | awk 'NR>1{print $NF}'); do
      for w in 0 1 2 3; do
        b="/backdrop/screen0/monitor$m/workspace$w"
        xfconf-query -c xfce4-desktop -p "$b/last-image" -n -t string -s "$IMG"
        xfconf-query -c xfce4-desktop -p "$b/image-style" -n -t int -s 5
      done
      [ "$(xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor$m/workspace0/last-image")" = "$IMG" ] && ok=1
      echo "monitor $m ok=$ok"
    done
    xfdesktop --reload
    [ "$ok" = 1 ] && touch "$M"
    ;;
  *GNOME*)
    gsettings set org.gnome.desktop.background picture-uri "file://$IMG"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$IMG"
    touch "$M"
    ;;
  *)
    echo "desktop nao reconhecido"
    ;;
esac
exit 0
