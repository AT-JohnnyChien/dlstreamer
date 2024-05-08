################################################################################
# Dockerfile to build an image for development of DL Streamer based on
# Ubuntu 20.04.
#
# It follow instructions given in [1] and [2] to install OpenVINO™ Runtime and
# prepare the environment for building DL Streamer from sources.
#
# This dockerfile is based on Ubuntu
#
# Author:
#   Johnny Chien <Johnny.Chien@at.govt.nz>
#
# Reviewer:
#   
#
# History:
#   2024-04-29 - Initial build by Johnny
#
# See also:
#  [1] https://dlstreamer.github.io/get_started/install/install_guide_ubuntu.html#option-3-compile-intel-dl-streamer-pipeline-framework-from-sources-on-host-system
#  [2] https://docs.openvino.ai/2024/get-started/install-openvino/install-openvino-archive-linux.html
#  [3] https://github.com/dlstreamer/dlstreamer/compare/master...OpenVINO-dev-contest:dlstreamer:yolov8-2023.0
#
#################################################// BEGIN OF BUILD OPTIONS //###
FROM ubuntu:20.04

# Runtime user
ARG RUNTIME_USER_ID="1001"
ARG RUNTIME_USERNAME="dev"
ARG RUNTIME_HOME="/home/dev"
ARG OPENVINO_INSTALL_DIR=/opt/intel/openvino_2024.1.0
ARG DLSTREAMER_SOIURCE_TREE=/home/${RUNTIME_USERNAME}/dlstreamer_gst

ARG DEBIAN_FRONTEND=noninteractive

LABEL description="This is the development image of Intel® Deep Learning Streamer (Intel® DL Streamer) Pipeline Framework"
LABEL vendor="Auckland Transport"

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Add runtime user
RUN useradd \
    -s /bin/bash \
    -d ${RUNTIME_HOME} -m \
    -u ${RUNTIME_USER_ID} \
    -g root \
    ${RUNTIME_USERNAME}

################################################################################
# Install OpenVINO™ Runtime on Linux from an Archive File
# See:
# - https://dlstreamer.github.io/get_started/install/install_guide_ubuntu.html#step-2-install-intel-distribution-of-openvino-toolkit
# - https://docs.openvino.ai/2024/get-started/install-openvino/install-openvino-archive-linux.html
################################################################################
WORKDIR /opt/intel

RUN apt-get update \
 && apt-get install -y -q --no-install-recommends curl=\* gpg=\* ca-certificates=\* gnupg=\* wget=\*  libtbb2=\* python3-pip=\* \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* 

# Download the OpenVINO Runtime archive file for your system, extract the files, rename the extracted folder and move it to the desired path
RUN curl -L https://storage.openvinotoolkit.org/repositories/openvino/packages/2024.1/linux/l_openvino_toolkit_ubuntu20_2024.1.0.15008.f4afc983258_x86_64.tgz --output openvino_2024.1.0.tgz \
 && tar -xf openvino_2024.1.0.tgz \
 && mv l_openvino_toolkit_ubuntu20_2024.1.0.15008.f4afc983258_x86_64 ${OPENVINO_INSTALL_DIR}

# Install required system dependencies on Linux.
WORKDIR ${OPENVINO_INSTALL_DIR}
RUN ./install_dependencies/install_openvino_dependencies.sh -y

# (Optional) Install numpy Python Library:
RUN python3 -m pip install -r ./python/requirements.txt

# Create a symbolic link to the OpenVINO installation directory
WORKDIR /opt/intel
RUN ln -s ${OPENVINO_INSTALL_DIR} openvino

# Install Open Model Zoo tools
RUN python3 -m pip install --upgrade pip \
 && python3 -m pip install openvino-dev[onnx,tensorflow,pytorch]

################################################################################
# Install Intel® DL Streamer Pipeline Framework dependencies
# See: https://dlstreamer.github.io/get_started/install/install_guide_ubuntu.html#step-3-install-intel-dl-streamer-pipeline-framework-dependencies
################################################################################

# Install build dependencies
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    curl wget gpg software-properties-common cmake build-essential \
    libpython3-dev python-gi-dev libopencv-dev jq \
    libgflags-dev libavcodec-dev libva-dev libavformat-dev libavutil-dev libswscale-dev \
 && apt-get clean

# Download pre-built Debian packages for GStreamer from GitHub Release page
RUN mkdir debs \
 && wget $(wget -q -O - https://api.github.com/repos/dlstreamer/dlstreamer/releases/latest | \
    jq -r '.assets[] | select(.name | contains (".deb")) | .browser_download_url') -P ./debs \
 && apt-get install -y -q ./debs/intel-dlstreamer-gst* \
 && apt-get install -y -q ./debs/intel-dlstreamer-ffmpeg* \
 && rm -rf debs \
 && apt-get clean


################################################################################
# Install Python dependencies
# See: https://dlstreamer.github.io/get_started/install/install_guide_ubuntu.html#step-4-install-python-dependencies
################################################################################

# Install Python requirements:
WORKDIR ${DLSTREAMER_SOIURCE_TREE}
COPY --chown=${RUNTIME_USER_ID}:root ./requirements.txt ./

RUN python3 -m pip install --upgrade pip \
 && python3 -m pip install -r requirements.txt

################################################################################
# Install message brokers
# See: https://dlstreamer.github.io/get_started/install/install_guide_ubuntu.html#step-6-install-message-brokers
################################################################################
# WORKDIR ${RUNTIME_HOME}/intel/dlstreamer_gst/scripts
# COPY --chown=${RUNTIME_USER_ID}:root ./scripts/install_metapublish_dependencies.sh ./

# RUN ./install_metapublish_dependencies.sh

# Copy the rest of source tree
USER ${RUNTIME_USER_ID}
WORKDIR ${DLSTREAMER_SOIURCE_TREE}
COPY --chown=${RUNTIME_USER_ID}:root ./ ./

ENV PKG_CONFIG_PATH "${PKG_CONFIG_PATH}:/usr/lib/x86_64-linux-gnu/pkgconfig"
WORKDIR ${DLSTREAMER_SOIURCE_TREE}/build

# source /opt/intel/openvino/setupvars.sh && source /opt/intel/dlstreamer/gstreamer/setupvars.sh

ARG CMAKE_BUILD_ARGS="\
    -DBUILD_EXAMPLES=OFF \
    -DENABLE_SAMPLES=OFF \
    -DCMAKE_INSTALL_PREFIX:PATH=/opt/intel/dlstreamer"

USER root

RUN source /opt/intel/openvino/setupvars.sh \
 && source /opt/intel/dlstreamer/gstreamer/setupvars.sh \
 && cmake ${CMAKE_BUILD_ARGS} .. \
 && make -j \
 && make install
