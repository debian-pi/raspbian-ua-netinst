# raspbian-ua-netinst Docker scripts

This directory contains a Dockerfile that is used to build the raspbian-ua-netinst docker hub image (https://hub.docker.com/r/goranche/raspbian-ua-netinst)

## TL;DR:

On a host with docker installed (and running), execute the following from the repository root directory:

`docker/buildroot.sh`

This will run a docker container from image `goranche/raspbian-ua-netinst`, and build the installer images.
The result will be the same as running `./update.sh`, `./build.sh` and `./buildroot.sh` on a Linux host, but one doesn't have to install any dependencies, and this docker image will work on macOS as well.
(Running the build on a Mac was the main reason for writing this)

## Fetch the image

`docker pull goranche/raspbian-ua-netinst`

## Run the image

To build an installer from the current directory (must be the root of a [raspbian-ua-netinst](git@github.com:debian-pi/raspbian-ua-netinst.git) repository):

`docker run --privileged -ti --rm -v $(pwd):/raspbian-ua-netinst goranche/raspbian-ua-netinst`

or, just run the `buildroot.sh` script from the docker directory, which will run the docker command for you:

`docker/buildroot.sh`

## Build the image

If for some reason you want to build the docker image yourself, run the following command in the docker directory:

`docker build -t <myname> .`

If you build your own image, you can still use the `docker/buildroot.sh` command, just add the name of your local image as an argument:

`docker/buildroot.sh <myname>`

For most cases, just running the prebuilt image should suffice.
