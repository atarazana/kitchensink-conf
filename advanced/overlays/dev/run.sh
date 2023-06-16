#!/bin/sh
ARGOCD_APP_NAME=events
BASE_REPO_URL=https://github.com/atarazana/gramola
NAMESPACE_SUFFIX="-user1"
BASE_NAMESPACE=demo-6
helm template ../../helm_base --name-template $ARGOCD_APP_NAME --set debug=${DEBUG},baseNamespace=${BASE_NAMESPACE},baseRepoUrl=${BASE_REPO_URL} --include-crds > ../../helm_base/all.yml && kustomize build | sed "s/\(namespace:[[:space:]]\{1,\}\)\(gramola-.*\)/\1\2${NAMESPACE_SUFFIX}/"