#!/bin/sh

. ./image-env.sh

podman run -u 12345 -it --rm $REGISTRY/$REGISTRY_USER_ID/${PROJECT_ID}:${JVM_VERSION} bash
