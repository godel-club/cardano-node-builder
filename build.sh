#!/bin/bash

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#Create Distribution Directory
DIST_DIR=$HERE/dist/
mkdir -p $DIST_DIR

#Build Cardano Image
DOCKER_TAG=cardano-dep:latest
docker build -t ${DOCKER_TAG} .

#Copy Cardano Binaries to Distribution Directory
DOCKER_TEMP_CONTAINER=cardanotemp
docker container create --name ${DOCKER_TEMP_CONTAINER} ${DOCKER_TAG}
docker container cp ${DOCKER_TEMP_CONTAINER}:/CARDANO_VERSION $DIST_DIR
docker container cp ${DOCKER_TEMP_CONTAINER}:/cardano-node-$(<$DIST_DIR/CARDANO_VERSION).tar.gz $DIST_DIR
docker container rm ${DOCKER_TEMP_CONTAINER}
rm $DIST_DIR/CARDANO_VERSION
