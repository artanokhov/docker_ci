# Copyright (C) 2019-2020 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
FROM ubuntu:18.04 as base

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
      gnupg \
      python3-minimal \
      python3-pip

ARG build_id
# Install full package
RUN curl -o GPG-PUB-KEY-INTEL-OPENVINO-2020 https://apt.repos.intel.com/openvino/2020/GPG-PUB-KEY-INTEL-OPENVINO-2020 && \
    apt-key add GPG-PUB-KEY-INTEL-OPENVINO-2020 && \
    echo "deb https://apt.repos.intel.com/openvino/2020 all main" | tee - a /etc/apt/sources.list.d/intel-openvino-2020.list && \
    apt-get update && apt-get install -y --no-install-recommends intel-openvino-dev-ubuntu18-"${build_id}" && \
    rm -rf /var/lib/apt/lists/*

# Install Python and some dependencies for deployment manager
RUN pip3 install setuptools
RUN pip3 install pytest-shutil

# Create CPU only package
RUN mkdir openvino_pkg
RUN /bin/bash -c "source /opt/intel/openvino/bin/setupvars.sh" && \
    python3 /opt/intel/openvino/deployment_tools/tools/deployment_manager/deployment_manager.py \
        --targets cpu \
        --output_dir openvino_pkg \
        --archive_name openvino_deploy_package

RUN cp -r /opt/intel/openvino/deployment_tools/inference_engine/share . && \
    cp -r /opt/intel/openvino/deployment_tools/ngraph/cmake ngraph_cmake && \
    cp -r /opt/intel/openvino/deployment_tools/ngraph/include ngraph_include && \
    cp -r /opt/intel/openvino/deployment_tools/inference_engine/include . && \
    cp -r /opt/intel/openvino/licensing . && \
    cp /opt/intel/openvino/deployment_tools/inference_engine/lib/intel64/libinference_engine_c_api.so . && \
    cp /opt/intel/openvino/bin/setupvars.sh setupvars.sh

# Replace full package by CPU package
RUN rm -r /opt/intel/ && mkdir -p /opt/intel/openvino_"${build_id}" && \
    tar -xf /openvino_pkg/openvino_deploy_package.tar.gz -C /opt/intel/openvino_"${build_id}" && \
    ln --symbolic /opt/intel/openvino_"${build_id}"/ /opt/intel/openvino && \
    mv setupvars.sh /opt/intel/openvino/bin && \
    mv /licensing /opt/intel/openvino/licensing && \
    mv /share /opt/intel/openvino/deployment_tools/inference_engine/share && \
    mv /include /opt/intel/openvino/deployment_tools/inference_engine/include && \
    mv /libinference_engine_c_api.so /opt/intel/openvino/deployment_tools/inference_engine/lib/intel64/ && \
    mv /ngraph_cmake /opt/intel/openvino/deployment_tools/ngraph/cmake && \
    mv /ngraph_include /opt/intel/openvino/deployment_tools/ngraph/include

FROM ubuntu:18.04

LABEL Description="This is the base CPU only image for Intel(R) Distribution of OpenVINO(TM) toolkit on Ubuntu 18.04 LTS"
LABEL Vendor="Intel Corporation"

COPY --from=base /opt/intel /opt/intel
RUN echo "source /opt/intel/openvino/bin/setupvars.sh" | tee -a /root/.bashrc

# Creating user openvino
RUN useradd -ms /bin/bash -G users openvino && \
    chown openvino -R /home/openvino

USER openvino

RUN echo "source /opt/intel/openvino/bin/setupvars.sh" | tee -a /home/openvino/.bashrc

WORKDIR /opt/intel/openvino

CMD ["/bin/bash"]
