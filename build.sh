#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

tmp_dir=$(mktemp -d)
cd "${tmp_dir}" || exit 1

git clone https://github.com/canonical/ubuntu-image
cd ubuntu-image || exit 1
git checkout 7a3c433455dbe5f4c66fe53aa885c04b4af85a1d
touch ubuntu-image.rst
sed -i 's/               golang-go (>= 2:1.21~),/               golang-go (>= 2:1.17~),/g' debian/control
sudo apt -y build-dep .
dpkg-buildpackage -us -uc
sudo dpkg -i ../*.deb

rm -rf "${tmp_dir}"

ubuntu-image classic -w work -O out ubuntu-rockchip-arm64-tarball.yaml 

