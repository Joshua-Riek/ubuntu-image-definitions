#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

pushd .

tmp_dir=$(mktemp -d)
cd "${tmp_dir}" || exit 1

git clone https://github.com/canonical/ubuntu-image
cd ubuntu-image || exit 1
git checkout 7a3c433455dbe5f4c66fe53aa885c04b4af85a1d
touch ubuntu-image.rst

apt-get update
apt-get build-dep . -y

dpkg-buildpackage -us -uc
apt-get install ../*.deb --assume-yes --allow-downgrades 
dpkg -i ../*.deb

rm -rf "${tmp_dir}"

popd 

ubuntu-image classic -w work -O out ubuntu-noble-arm64-tarball.yaml

