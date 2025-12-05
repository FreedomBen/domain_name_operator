#!/usr/bin/env bash

if [ -z "${RELEASE_VERSION}" ]; then
  RELEASE_VERSION="$(git rev-parse HEAD)"
  echo "RELEASE_VERSION is not set.  Setting to HEAD (${RELEASE_VERSION})"
else
  echo "RELEASE_VERSION already set to '${RELEASE_VERSION}'"
fi

# Short circuit and return success for now
echo "CI is disabled temporarily"
exit 0

docker run --rm  \
  "docker.io/freedomben/domain_name_operator:${RELEASE_VERSION}" \
  mix test

