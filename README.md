# Gödel Cardano Node Builder

The Gödel Cardano Node Builder allows you to build the Cardano CLIs
and all of their dependencies locally and easily install them
on remote servers.

Because the binaries are built locally, you will no longer need to
install all of the build dependencies on your remote server. The
builder checks that dependencies are met on a fresh Ubuntu 20.04
installation.

## Due Diligence

We at `godel.club` are honest folks that want to contribute to
making Cardano better, more reliable, and easier for people to use.

However, keep in mind that a tool like this could create an opportunity
for malicious behavior from a bad actor. If you intend to use a tool like
this one (including this one!) look through the source files to make sure that
everything is being built from trusted sources.

## Installation

You must have [docker](https://docs.docker.com/get-docker/)
installed to run the builder.

Clone this repository.

```sh
git clone https://github.com/godel-club/cardano-node-builder
cd cardano-node-builder
```

## Usage

To build the binaries, simply run:

```sh
./build.sh
```

The build should take 30 minutes to an hour to complete
depending on your system. It may look as though the build is hanging
from time to time but this is expected behavior.

Once the build is finished, you should see an archive in the `dist/`
directory called `cardano-node-<version>.tar.gz` where `<version>`
is the version of the CLIs (eg. `1.25.1`).

Copy the archive to your remote server.

```sh
scp dist/cardano-node-<version>.tar.gz <user>@<remote ip>:
```

Log in to the remote server and install the binaries.

```sh
ssh <user>@<remote ip>
sudo tar -zxvf cardano-node-<version>.tar.gz -C /
rm cardano-node-<version>.tar.gz
```

Test to make sure that everything was installed correctly:

```sh
cardano-node version
cardano-cli version
```
