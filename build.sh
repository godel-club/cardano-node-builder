#!/bin/bash

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#Create Distribution Directory
DIST_DIR=$HERE/dist/
mkdir -p $DIST_DIR

#Build Cardano Image
DOCKER_TAG=cardano-dep:latest
docker build -t ${DOCKER_TAG} .
retval=$?
if [ $retval -ne 0 ]; then
    >&2 echo "Build exited with code $retval."
    exit $retval
fi

#Copy Cardano Binaries to Distribution Directory
DOCKER_TEMP_CONTAINER=cardanotemp
docker container create --name ${DOCKER_TEMP_CONTAINER} ${DOCKER_TAG}
docker container cp ${DOCKER_TEMP_CONTAINER}:/CARDANO_VERSION $DIST_DIR
CARDANO_ARCHIVE=cardano-node-$(<$DIST_DIR/CARDANO_VERSION).tar.gz
docker container cp ${DOCKER_TEMP_CONTAINER}:/$CARDANO_ARCHIVE $DIST_DIR
docker container rm ${DOCKER_TEMP_CONTAINER}
rm $DIST_DIR/CARDANO_VERSION

echo "Build archive available at ${DIST_DIR}/${CARDANO_ARCHIVE}"
