#!/usr/bin/env bash
case $1 in
d)
  cliphist list | rofi -dmenu -replace -config $HOME/my-env/rofi/rose-pine.rasi | cliphist delete
  ;;

w)
  if [ $(echo -e "Clear\nCancel" | rofi -dmenu -config $HOME/my-env/rofi/rose-pine.rasi) == "Clear" ]; then
    cliphist wipe
  fi
  ;;

*)
  cliphist list | rofi -dmenu -replace -theme $HOME/my-env/rofi/rose-pine.rasi | cliphist decode | wl-copy
  ;;
esac
