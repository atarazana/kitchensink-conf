#!/bin/sh
ARGOCD_APP_NAME=kitchensink
BASE_REPO_URL=https://github.com/atarazana/kitchensink-conf
BASE_NAMESPACE=demo-test
helm template ../../helm_base --name-template $ARGOCD_APP_NAME --set debug=${ARGOCD_ENV_DEBUG},baseNamespace=${ARGOCD_ENV_BASE_NAMESPACE},clusterName=${ARGOCD_ENV_DESTINATION_NAME},gitUrl=${ARGOCD_ENV_GIT_URL},gitUsername=${ARGOCD_ENV_GIT_USERNAME},baseRepoName=${ARGOCD_ENV_BASE_REPO_NAME},gitRevision=${ARGOCD_ENV_GIT_REVISION}  --include-crds > ../../helm_base/all.yml && kustomize build