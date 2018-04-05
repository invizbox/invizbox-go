#!/bin/bash

echo "Preparing the lede directory..."

resources/clone_or_update.bash lede

rsync -avh  src/files/ lede/files/ --delete

cp src/feeds.conf lede/feeds.conf

cd lede
./scripts/feeds update -a
./scripts/feeds install -a

sed "s,@HOME_DIR@,"$HOME"," ../src/.config > .config

make defconfig

echo "lede directory ready!"

nice -n 19 make -j $(($(grep -c processor /proc/cpuinfo)))
