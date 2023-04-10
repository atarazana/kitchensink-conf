
#!/bin/sh

CURRENT_DIR=$(pwd)
cd $(dirname $0)

. ./image-env.sh

./mvnw clean package -DskipTests

podman build -f src/main/docker/Dockerfile.jvm --build-arg FROM_IMAGE=${FROM_IMAGE} -t ${PROJECT_ID}-${ARTIFACT_ID}:${GIT_HASH} .

podman tag ${PROJECT_ID}-${ARTIFACT_ID}:${GIT_HASH} ${PROJECT_ID}-${ARTIFACT_ID}:${ARTIFACT_VERSION}

cd ${CURRENT_DIR}