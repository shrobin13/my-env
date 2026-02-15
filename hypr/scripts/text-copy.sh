#!/usr/bin/env bash
grim -g "$(slurp)" - | tesseract - - | wl-copy
