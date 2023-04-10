#!/bin/sh

if [ "$1" != "11" ] && [ "$1" != "17" ]; then
    echo "$0 11 or 17"
    exit 1
fi

JVM_VERSION=$1

. ./image-env.sh

podman tag ${PROJECT_ID}:${JVM_VERSION} $REGISTRY/$REGISTRY_USER_ID/${PROJECT_ID}:${JVM_VERSION}
podman tag ${PROJECT_ID}:${JVM_VERSION} $REGISTRY/$REGISTRY_USER_ID/${PROJECT_ID}:latest

podman push $REGISTRY/$REGISTRY_USER_ID/${PROJECT_ID}:${JVM_VERSION}
podman push $REGISTRY/$REGISTRY_USER_ID/${PROJECT_ID}:latest
