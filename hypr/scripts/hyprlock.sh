#!/usr/bin/env bash
# Avoid starting multiple hyprlock instances
pidof hyprlock >/dev/null || hyprlock
