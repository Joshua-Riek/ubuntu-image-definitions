#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

docker build -t foobar docker
docker run --privileged -v /dev:/dev --rm -v "$(pwd)":/opt foobar ./build.sh
