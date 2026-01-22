FROM balenalib/raspberrypi4-64-debian:bookworm-run

# 安装基础工具和依赖
RUN install_packages \
        i2c-tools \
        can-utils \
        minicom \
        cmake \
        make \
        gcc \
        g++ \
        libopencv-dev \
        alsa-utils \
        libasound2 \
        libasound2-dev \
        libtool \
        autoconf \
        automake \
        pkg-config \
        iperf3 \
        git \
        wget \
        ca-certificates

# Hailo 相关工具安装
# 这里假设你有 hailo-firmware 和 hailortcli 的安装包或源码
# 你可以 COPY 它们进容器或者从网络下载
# 下面示例从 GitHub（仅示意，具体根据实际情况调整）

# RUN git clone https://github.com/HailoAI/hailort.git /hailort && \
#     cd /hailort && \
#     ./configure && make && make install

# 如果有预编译二进制，拷贝进容器
# COPY hailo_tools/hailo-firmware /usr/local/bin/
# COPY hailo_tools/hailortcli /usr/local/bin/
# RUN chmod +x /usr/local/bin/hailo-firmware /usr/local/bin/hailortcli

COPY Canon.wav /usr/local/share/sounds/Canon.wav

RUN cd /usr/local/share && git clone https://github.com/hailo-ai/hailort.git -b hailo8 --depth=10 && \
        cd hailort && git checkout 542ba8f3cd95ed85175083ee4add00167c50f668 && \
        mkdir build && cd build && \
        cmake .. && make -j4 && make install

RUN cd /usr/local/share && git clone https://github.com/hailo-ai/Hailo-Application-Code-Examples.git --depth=10 && \
        cd Hailo-Application-Code-Examples/runtime/hailo-8/cpp/classifier && \
        ./get_hef.sh

CMD ["/bin/bash"]
