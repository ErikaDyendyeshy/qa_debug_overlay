#!/usr/bin/env bash
# Encodes frames from tool/demo/record_demo_test.dart into the README demo.
set -euo pipefail
cd "$(dirname "$0")/../.."

frames=build/demo_frames
mkdir -p doc/screenshots

# MP4 for GitHub (sharp, small).
ffmpeg -y -loglevel error -framerate 25 -i "$frames/frame_%05d.png" \
  -vf "scale=1040:-2:flags=lanczos,format=yuv420p" \
  -c:v libx264 -preset slow -crf 22 -movflags +faststart doc/demo.mp4

# GIF for pub.dev (README images only).
ffmpeg -y -loglevel error -framerate 25 -i "$frames/frame_%05d.png" \
  -vf "fps=15,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
  doc/demo.gif

# Static screenshot for pub.dev's gallery.
ffmpeg -y -loglevel error -i "$frames/preview.png" -vf "scale=1040:-1:flags=lanczos" \
  doc/screenshots/preview.png

ls -lh doc/demo.gif doc/demo.mp4 doc/screenshots/preview.png
