
#!/bin/sh

. ./image-env.sh

podman build -f Containerfile --build-arg UBI8_TAG=${UBI8_TAG} --build-arg JVM_VERSION=${JVM_VERSION} -t ${PROJECT_ID}:${JVM_VERSION} .
