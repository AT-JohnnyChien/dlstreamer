# ==============================================================================
# Copyright (C) 2022-2024 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

LABEL description="This is the runtime image of Intel® Deep Learning Streamer (Intel® DL Streamer) Pipeline Framework"
LABEL vendor="Intel Corporation"

ARG DLSTREAMER_VERSION=2024.0
ARG OPENVINO_FILENAME=l_openvino_toolkit_ubuntu22_2024.0.0.14509.34caeefd078_x86_64

USER root

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

RUN apt-get update && \
    apt-get install -y -q --no-install-recommends gpg=\* ca-certificates=\* gnupg=\* wget=\* libtbb12=\* python3-pip=\* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/ssl/certs/Intel*

# Intel® VPU drivers (optional)
RUN \
    mkdir debs && \
    dpkg --purge --force-remove-reinstreq intel-driver-compiler-npu intel-fw-npu intel-level-zero-npu level-zero && \
    wget -q https://github.com/intel/linux-npu-driver/releases/download/v1.2.0/intel-driver-compiler-npu_1.4.0.20240322-8393323322_ubuntu22.04_amd64.deb -P ./debs && \
    wget -q https://github.com/intel/linux-npu-driver/releases/download/v1.2.0/intel-fw-npu_1.4.0.20240322-8393323322_ubuntu22.04_amd64.deb -P ./debs && \
    wget -q https://github.com/intel/linux-npu-driver/releases/download/v1.2.0/intel-level-zero-npu_1.4.0.20240322-8393323322_ubuntu22.04_amd64.deb -P ./debs && \
    wget -q https://github.com/oneapi-src/level-zero/releases/download/v1.16.1/level-zero_1.16.1+u22.04_amd64.deb -P ./debs && \
    dpkg -i ./debs/*.deb && \
    rm -rf debs

# Intel® Data Center GPU Flex Series drivers (optional)
# hadolint ignore=SC1091
RUN \
    apt-get update && \
    . /etc/os-release && \
    if [[ ! "jammy" =~ ${VERSION_CODENAME} ]]; then \
        echo "Ubuntu version ${VERSION_CODENAME} not supported"; \
    else \
        wget -qO- https://repositories.intel.com/gpu/intel-graphics.key | gpg --dearmor --output /usr/share/keyrings/gpu-intel-graphics.gpg && \
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/gpu-intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu ${VERSION_CODENAME}/lts/2350 unified" | \
        tee /etc/apt/sources.list.d/intel-gpu-"${VERSION_CODENAME}".list && \
        apt-get update; \
    fi && \
    apt-get install -y --no-install-recommends linux-headers-"$(uname -r)"=\* flex=\* bison=\* intel-fw-gpu=\* intel-i915-dkms=\* xpu-smi=\* \
    intel-opencl-icd=\* intel-level-zero-gpu=\* level-zero=\* \
    intel-media-va-driver-non-free=\* libmfx1=\* libmfxgen1=\* libvpl2=\* \
    libegl-mesa0=\* libegl1-mesa=\* libegl1-mesa-dev=\* libgbm1=\* libgl1-mesa-dev=\* libgl1-mesa-dri=\* \
    libglapi-mesa=\* libgles2-mesa-dev=\* libglx-mesa0=\* libigdgmm12=\* libxatracker2=\* mesa-va-drivers=\* \
    mesa-vdpau-drivers=\* mesa-vulkan-drivers=\* va-driver-all=\* vainfo=\* hwinfo=\* clinfo=\* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/ssl/certs/Intel*

ENV INTEL_SW_KEY_URL=https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB

ARG GRAPHICS_KEY_URL=https://repositories.intel.com/graphics/intel-graphics.key
ARG GRAPHICS_APT_REPO="deb https://repositories.intel.com/graphics/ubuntu jammy flex"
ARG DPCPP_APT_VERSION=*
ARG ONEAPI_APT_REPO="deb https://apt.repos.intel.com/oneapi all main"
ARG ONEAPI_KEY_URL="$INTEL_SW_KEY_URL"

# Intel® DL Streamer Pipeline Framework
# Intel® Distribution of OpenVINO™ Toolkit
# Intel® oneAPI DPC++/C++ Compiler
RUN wget -q "$INTEL_SW_KEY_URL" && \
    apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
    rm GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
    repo="$GRAPHICS_APT_REPO" && \
    if [ -n "$GRAPHICS_KEY_URL" ]; then \
        key=/usr/share/keyrings/intel-graphics.gpg && \
        wget -qO- "$GRAPHICS_KEY_URL" | gpg --dearmor --output "$key" && \
        repo="${repo//deb /deb [signed-by=$key] }"; \
    fi && \
    echo "$repo" > /etc/apt/sources.list.d/intel-graphics.list && \
    repo="$ONEAPI_APT_REPO" && \
    if [ -n "$ONEAPI_KEY_URL" ]; then \
        key=/usr/share/keyrings/intel-oneapi.gpg; \
        if [ ! -f "$key" ]; then \
            wget -qO- "$ONEAPI_KEY_URL" | gpg --dearmor --output "$key"; \
        fi && \
        repo="${repo//deb /deb [signed-by=$key] }"; \
    fi && \
    echo "$repo" > /etc/apt/sources.list.d/intel-oneapi.list && \
    apt-get update && \
    apt-get install -y -q --no-install-recommends level-zero=\* intel-level-zero-gpu=\* librdkafka-dev=\* libpaho-mqtt-dev=\* && \
    wget -q https://storage.openvinotoolkit.org/repositories/openvino/packages/2024.0/linux/"$OPENVINO_FILENAME".tgz && \
    tar -xf "$OPENVINO_FILENAME".tgz && \
    mkdir /opt/intel/ && \
    mv "$OPENVINO_FILENAME" /opt/intel/openvino_2024.0.0 && \
    rm "$OPENVINO_FILENAME".tgz && \
    /opt/intel/openvino_2024.0.0/install_dependencies/install_openvino_dependencies.sh -y && \
    wget -q -nH --accept-regex="\.deb" --cut-dirs=5 -r https://github.com/dlstreamer/dlstreamer/releases/expanded_assets/v"$DLSTREAMER_VERSION" -P ./debs && \
    apt-get install -y -q --no-install-recommends ./debs/*.deb && \
    rm -r -f debs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/ssl/certs/Intel*

ENV DLSTREAMER_DIR=/opt/intel/dlstreamer
ENV INTEL_OPENVINO_DIR=/opt/intel/openvino_2024.0.0

# OpenVINO environment variables
ENV OpenVINO_DIR="$INTEL_OPENVINO_DIR/runtime/cmake"
ENV InferenceEngine_DIR="$INTEL_OPENVINO_DIR/runtime/cmake"
ENV ngraph_DIR="$INTEL_OPENVINO_DIR/runtime/cmake"
ENV HDDL_INSTALL_DIR="$INTEL_OPENVINO_DIR/runtime/3rdparty/hddl"
ENV TBB_DIR="$INTEL_OPENVINO_DIR/runtime/3rdparty/tbb/cmake"
ENV LD_LIBRARY_PATH="$INTEL_OPENVINO_DIR/tools/compile_tool:$INTEL_OPENVINO_DIR/runtime/3rdparty/tbb/lib:$INTEL_OPENVINO_DIR/runtime/3rdparty/hddl/lib:$INTEL_OPENVINO_DIR/runtime/lib/intel64:$LD_LIBRARY_PATH"
ENV PYTHONPATH="$INTEL_OPENVINO_DIR/python/${PYTHON_VERSION}:$PYTHONPATH"

# DL Streamer environment variables
ENV GSTREAMER_DIR="${DLSTREAMER_DIR}/gstreamer"
ENV GST_PLUGIN_PATH="${DLSTREAMER_DIR}/lib/gstreamer-1.0:${GSTREAMER_DIR}/lib/gstreamer-1.0:/opt/intel/dlstreamer/gstreamer/lib/gstreamer-1.0:/usr/lib/x86_64-linux-gnu/gstreamer-1.0:${GST_PLUGIN_PATH}"
ENV LIBRARY_PATH="${DLSTREAMER_DIR}/lib:${DLSTREAMER_DIR}/lib/gstreamer-1.0:/usr/lib:${LIBRARY_PATH}"
ENV LD_LIBRARY_PATH="${DLSTREAMER_DIR}/lib:${DLSTREAMER_DIR}/lib/gstreamer-1.0:/usr/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="${DLSTREAMER_DIR}/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
ENV MODELS_PATH="${MODELS_PATH:-${DLS_HOME}/intel/dl_streamer/models}"
ENV LC_NUMERIC="C"
ENV C_INCLUDE_PATH="${DLSTREAMER_DIR}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${DLSTREAMER_DIR}/include:${CPLUS_INCLUDE_PATH}"

# if USE_CUSTOM_GSTREAMER set, add GStreamer build to GST_PLUGIN_SCANNER and PATH
ARG USE_CUSTOM_GSTREAMER=yes
ENV GST_PLUGIN_SCANNER="${USE_CUSTOM_GSTREAMER:+${GSTREAMER_DIR}/bin/gstreamer-1.0/gst-plugin-scanner}"
ENV GI_TYPELIB_PATH="${USE_CUSTOM_GSTREAMER:+${GSTREAMER_DIR}/lib/girepository-1.0}"
ENV PATH="${USE_CUSTOM_GSTREAMER:+${GSTREAMER_DIR}/bin:}${PATH}"
ENV PKG_CONFIG_PATH="${USE_CUSTOM_GSTREAMER:+${GSTREAMER_DIR}/lib/pkgconfig:}${PKG_CONFIG_PATH}"
ENV LIBRARY_PATH="${USE_CUSTOM_GSTREAMER:+${GSTREAMER_DIR}/lib:}$LIBRARY_PATH"
ENV LD_LIBRARY_PATH="${USE_CUSTOM_GSTREAMER:+${GSTREAMER_DIR}/lib:}$LD_LIBRARY_PATH"
ENV PYTHONPATH="${USE_CUSTOM_GSTREAMER:+${GSTREAMER_DIR}/lib/python3/dist-packages:}$PYTHONPATH"

# DPC++ runtime
ENV DPCPP_DIR="/opt/intel/oneapi/compiler/latest/linux"
ENV PATH="${PATH}:${DPCPP_DIR}/lib:${DPCPP_DIR}/compiler/lib/intel64_lin"
ENV LIBRARY_PATH="${LIBRARY_PATH}:${DPCPP_DIR}/lib:${DPCPP_DIR}/compiler/lib/intel64_lin"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${DPCPP_DIR}/lib:${DPCPP_DIR}/lib/x64:${DPCPP_DIR}/compiler/lib/intel64_lin:/opt/intel/oneapi/compiler/latest/lib"

# Setup enviroment variables using installed packages
# hadolint ignore=SC1091
RUN . "$INTEL_OPENVINO_DIR"/setupvars.sh && \
    . "$DLSTREAMER_DIR"/setupvars.sh && \
    . "$DLSTREAMER_DIR"/gstreamer/setupvars.sh && \
    . /opt/intel/oneapi/setvars.sh

# Setup Python environment
RUN pip install --no-cache-dir --upgrade pip==24.0 && \
    pip install --no-cache-dir --no-dependencies \
    numpy==1.23.5 \
    tabulate==0.9.0 \
    tqdm==4.66.2 \
    junit-xml==1.9 \
    opencv-python==4.9.0.80 \
    XlsxWriter==3.2.0 \
    zxing-cpp==2.2.0 \
    pyzbar==0.1.9 \
    six==1.16.0

ENV PYTHONPATH=/opt/intel/dlstreamer/gstreamer/lib/python3/dist-packages:/home/dlstreamer/dlstreamer/python:${PYTHONPATH}

RUN useradd -ms /bin/bash -G video dlstreamer && usermod -aG render dlstreamer && ln -s /opt/intel/dlstreamer /home/dlstreamer/dlstreamer

WORKDIR /home/dlstreamer
USER dlstreamer

CMD ["/bin/bash"]
