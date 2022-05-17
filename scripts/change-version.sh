#!/usr/bin/env bash

#NEW_VERSION="2021-08-19"
#NEW_VERSION="$(date '+%Y-%m-%d-%H-%M-%S')"
NEW_VERSION="$(date '+%Y%m%d%H%M%S')"

K8S_FILES=("k8s/staging/deploy.yaml" "k8s/staging/migrate.yaml" "k8s/prod/deploy.yaml" "k8s/prod/migrate.yaml")

for f in $(findref --no-color '^LATEST_VERSION' | awk -F : '{ print $1 }' | sort | uniq); do
  sed -i -e "s/^LATEST_VERSION=.*/LATEST_VERSION='${NEW_VERSION}'/g" "$f"
done

#for f in ${K8S_FILES[@]}; do
#  sed -i -E -e "s|image: docker.io/freedomben/domain-name-operator-(.*):.*|image: docker.io/freedomben/domain-name-operator-\1:${NEW_VERSION}|g" "$f"
#done

for f in ${K8S_FILES[@]}; do
  sed -i -E -e "s|image: docker.io/freedomben/domain_name_operator(.*):.*|image: docker.io/freedomben/domain_name_operator:${NEW_VERSION}|g" "$f"
done
