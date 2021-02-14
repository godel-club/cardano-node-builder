# Cardano CLI version
ARG CARDANO_VERSION="1.25.1"

# libsodium git commit
ARG SODIUM_COMMIT=66f017f1

# Cabal Version
ARG CABAL_VERSION="3.2.0.0"

# GHC Version
ARG GHC_VERSION="8.10.2"

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

RUN mkdir -p $DEP_DIR/FS_LIB_PREFIX $DEP_DIR/FS_BIN_PREFIX $DEP_DIR/FS_SHARE_PREFIX

# Source Directory
ENV SRC_DIR=$DEP_DIR/src

# Install Cabal
ENV CABAL_DIR=$SRC_DIR/cabal
WORKDIR $CABAL_DIR
RUN wget https://downloads.haskell.org/~cabal/cabal-install-$CABAL_VERSION/cabal-install-$CABAL_VERSION-x86_64-unknown-linux.tar.xz \
    && tar -xf cabal-install-$CABAL_VERSION-x86_64-unknown-linux.tar.xz \
    && mv cabal /usr/local/bin \
    && cabal update && cabal --version

# Install GHC
ENV GHC_DIR=$SRC_DIR/ghc
WORKDIR $GHC_DIR
RUN wget https://downloads.haskell.org/ghc/$GHC_VERSION/ghc-$GHC_VERSION-x86_64-deb9-linux.tar.xz \
    && tar -xf ghc-$GHC_VERSION-x86_64-deb9-linux.tar.xz \
    && cd ghc-$GHC_VERSION \
    && ./configure \
    && make install

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

# Install Cardano Node
ENV CARDANO_DIR=$SRC_DIR/cardano
WORKDIR $CARDANO_DIR
RUN git clone https://github.com/input-output-hk/cardano-node.git \
    && cd cardano-node \
    && git fetch --all --recurse-submodules --tags \
    && git tag \
    && git checkout tags/$CARDANO_VERSION \
    && cabal configure --with-compiler=ghc-$GHC_VERSION \
    && echo "package cardano-crypto-praos" >>  cabal.project.local \
    && echo "  flags: -external-libsodium-vrf" >>  cabal.project.local \
    && cabal build all \
    && mkdir -p $DESTDIR/$FS_BIN_PREFIX \
    && cp -p dist-newstyle/build/x86_64-linux/ghc-$GHC_VERSION/cardano-node-$CARDANO_VERSION/x/cardano-node/build/cardano-node/cardano-node $DESTDIR/$FS_BIN_PREFIX \
    && cp -p dist-newstyle/build/x86_64-linux/ghc-$GHC_VERSION/cardano-cli-$CARDANO_VERSION/x/cardano-cli/build/cardano-cli/cardano-cli $DESTDIR/$FS_BIN_PREFIX

# Compress Binaries
RUN tar -zcvf /cardano-node-$CARDANO_VERSION.tar.gz -C $FS_DIR .
RUN echo $CARDANO_VERSION > /CARDANO_VERSION

# Testing server
FROM ubuntu:20.04

ARG CARDANO_VERSION
ARG SODIUM_COMMIT
ARG CABAL_VERSION
ARG GHC_VERSION

COPY --from=builder /cardano-node-$CARDANO_VERSION.tar.gz /
COPY --from=builder /CARDANO_VERSION /
