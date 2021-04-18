# Cardano CLI version
ARG CARDANO_VERSION="1.26.1"

# libsodium git commit
ARG SODIUM_COMMIT=66f017f1

# Cabal Version
ARG CABAL_VERSION="3.4.0.0"

# GHC Version
ARG GHC_VERSION="8.10.4"

# GHC Version
ARG FS_PREFIX=/usr/local/

# Builder Container
FROM ubuntu:20.04 AS builder

ARG CARDANO_VERSION
ARG SODIUM_COMMIT
ARG CABAL_VERSION
ARG GHC_VERSION

# GHC Version
ARG FS_PREFIX=/usr/local/

SHELL ["/bin/bash", "-c"]

ENV TZ=US/Mountain
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install build dependencies
RUN apt-get update -y \
    && apt-get install -y git jq bc make automake rsync htop curl build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ wget libncursesw5 libtool autoconf \
    && apt-get clean

# Base Build Directory
ENV DEP_DIR=/cardano-dep

# File System Directories
ENV FS_DIR=$DEP_DIR/fs
ENV FS_LIB_PREFIX=$FS_PREFIX/lib
ENV FS_BIN_PREFIX=$FS_PREFIX/bin
ENV FS_SHARE_PREFIX=$FS_PREFIX/share/cardano

RUN mkdir -p $FS_DIR/$FS_LIB_PREFIX $FS_DIR/$FS_BIN_PREFIX $FS_DIR/$FS_SHARE_PREFIX

# Source Directory
ENV SRC_DIR=$DEP_DIR/src

# Install Sodium
ENV SODIUM_DIR=$SRC_DIR/sodium
WORKDIR $SODIUM_DIR
RUN git clone https://github.com/input-output-hk/libsodium \
    && cd libsodium \
    && git checkout $SODIUM_COMMIT \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install \
    && make DESTDIR=$FS_DIR install
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" \
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

# Install GHC
ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | bash
RUN source ~/.ghcup/env \
    && ghcup upgrade

# Install Cabal
RUN source ~/.ghcup/env \
    && ghcup install cabal $CABAL_VERSION \
    && ghcup set cabal $CABAL_VERSION \
    && cabal update \
    && cabal --version

# Install GHC
RUN source ~/.ghcup/env \
    && ghcup install ghc $GHC_VERSION \
    && ghcup set ghc $GHC_VERSION \
    && ghc --version

# Install Cardano Node
ENV CARDANO_DIR=$SRC_DIR/cardano
WORKDIR $CARDANO_DIR
RUN source ~/.ghcup/env \
    && git clone https://github.com/input-output-hk/cardano-node.git \
    && cd cardano-node \
    && git fetch --all --recurse-submodules --tags \
    && git checkout tags/$CARDANO_VERSION \
    && cabal configure -O0 -w ghc-$GHC_VERSION \
    && echo "package cardano-crypto-praos" >>  cabal.project.local \
    && echo "  flags: -external-libsodium-vrf" >>  cabal.project.local \
    && sed -i $HOME/.cabal/config -e "s/overwrite-policy:/overwrite-policy: always/g" \
    && rm -rf $HOME/git/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.4 \
    && cabal build cardano-cli cardano-node

RUN cp $(find $CARDANO_DIR/cardano-node/dist-newstyle/build -type f -name "cardano-cli") $FS_DIR/$FS_BIN_PREFIX/cardano-cli \
    && cp $(find $CARDANO_DIR/cardano-node/dist-newstyle/build -type f -name "cardano-node") $FS_DIR/$FS_BIN_PREFIX/cardano-node

# Compress Binaries
RUN tar -zcvf /cardano-node-$CARDANO_VERSION.tar.gz -C $FS_DIR .
RUN echo $CARDANO_VERSION > /CARDANO_VERSION

# Testing server
FROM ubuntu:20.04 AS tester

ARG CARDANO_VERSION
ARG FS_PREFIX

# Extract Binary
COPY --from=builder /cardano-node-$CARDANO_VERSION.tar.gz /
COPY --from=builder /CARDANO_VERSION /

RUN tar -zxvf /cardano-node-$CARDANO_VERSION.tar.gz -C /

RUN ldconfig

RUN ls /usr/local/bin

# Test that linking is correct
RUN ldd -r $FS_PREFIX/bin/cardano-cli \
    && ldd -r $FS_PREFIX/bin/cardano-node

# Test that CLIs are executing correctly
RUN $FS_PREFIX/bin/cardano-cli version \
    && $FS_PREFIX/bin/cardano-node version

# Test tjat CLIs are resolvable in current path
RUN cardano-cli version \
    && cardano-node version
