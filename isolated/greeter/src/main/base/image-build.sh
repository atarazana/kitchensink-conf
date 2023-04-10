
#!/bin/sh

if [ "$1" != "11" ] && [ "$1" != "17" ]; then
    echo "$0 11 or 17"
    exit 1
fi

JVM_VERSION=$1

. ./image-env.sh

podman build -f Containerfile --build-arg UBI8_TAG=${UBI8_TAG} --build-arg JVM_VERSION=${JVM_VERSION} -t ${PROJECT_ID}:${JVM_VERSION} .
