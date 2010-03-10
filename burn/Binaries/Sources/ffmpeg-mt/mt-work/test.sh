#!/bin/bash

fn=`basename "$1"`
for th in 1 2 3 4; do
    time ./ffmpeg_g -threads $th -vsync 0 -y -t 30 -i "$1" -an -f framecrc "crc/$fn-$th.txt" >/dev/null 2>&1
done