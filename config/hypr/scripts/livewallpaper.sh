#!/bin/bash

# Kill previous wallpaper apps
pkill -f mpvpaper
pkill swaybg
pkill swww-daemon

sleep 0.2

# Start mpvpaper in background
# mpvpaper -o "loop=yes audio=no hwdec=vaapi video-aspect-override=16:9" HDMI-A-1 "$HOME/my-env/wallpapers/ancient.mp4" &
mpvpaper -o "loop=yes audio=no hwdec=vaapi video-aspect-override=16:9" eDP-1 "$HOME/my-env/wallpapers/optimized.mp4" &
