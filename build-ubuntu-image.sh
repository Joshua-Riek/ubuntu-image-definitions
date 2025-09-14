#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

tmp_dir=$(mktemp -d)
cd "${tmp_dir}" || exit 1

git clone https://github.com/Joshua-Riek/ubuntu-image
cd ubuntu-image || exit 1
touch ubuntu-image.rst

sudo apt-get update
sudo apt-get build-dep . -y

sudo dpkg-buildpackage -us -uc
sudo apt-get install ../*.deb --assume-yes --allow-downgrades 
sudo dpkg -i ../*.deb
sudo apt-mark hold ubuntu-image

sudo rm -rf "${tmp_dir}"
