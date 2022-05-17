#!/usr/bin/env bash

LATEST_VERSION='20220401110701'

docker build \
  -f Dockerfile \
  -t "docker.io/freedomben/domain-name-operator-dev:${LATEST_VERSION}" \
  -t "docker.io/freedomben/domain-name-operator-dev:latest" \
  .
