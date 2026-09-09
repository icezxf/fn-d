FROM debian:12.12 AS builder

COPY ./fnos.iso ./fnos.iso
COPY fakebroker.go ./fakebroker.go
COPY init.sql ./init.sql
COPY entrypoint.sh ./entrypoint.sh
COPY manifest ./manifest

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
  apt update && apt install -y p7zip-full curl && 7z x fnos.iso -ofniso && \
  cd /fniso && tar -xvf trimfs.tgz --strip-components=1 ./usr/trim/bin/mediasrv ./usr/trim/lib/libnebula.so ./usr/trim/lib/libppjson.so ./usr/trim/lib/mediasrv && \
  mkdir -p /fniso/usr/trim/etc && mv /entrypoint.sh /init.sql /fniso/usr/trim/ && \
  GOPKG=go1.24.10.linux-arm64 && curl -O https://dl.google.com/go/${GOPKG}.tar.gz && \
  tar -C /opt -xvf ${GOPKG}.tar.gz && \
  GOARCH=arm64 /opt/go/bin/go build -o /fniso/usr/trim/bin/rpcbroker /fakebroker.go

FROM --platform=linux/arm64 debian:12.12

ENV LD_LIBRARY_PATH=/usr/trim/lib/mediasrv LOG_LEVEL=info MEDIA_DIRS=/vol1/1000/media

COPY --from=builder /fniso/usr/trim /usr/trim
ADD ./trim.media.tar.gz /usr/local/apps/@appcenter/

RUN mkdir -p /var/apps/trim.media/
COPY --from=builder /manifest /var/apps/trim.media/manifest

WORKDIR /usr/trim

# 安装所有依赖包
RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
  apt update && apt install -y \
  # 原有依赖（保持不变）
  sqlite3 \
  openssl \
  ca-certificates \
  libass9 \
  libbluray2 \
  libmp3lame0 \
  libopenmpt0 \
  libopus0 \
  libtcmalloc-minimal4 \
  libtheora0 \
  libvorbisenc2 \
  libvpx7 \
  libwebp7 \
  libwebpmux3 \
  libx264-164 \
  libx265-199 \
  libzvbi0 \
  # 🆕 新增：VA-API 硬件加速（解决 libva.so.2）
  libva2 \
  libva-drm2 \
  libva-x11-2 \
  # 🆕 新增：内存分配器（解决 libjemalloc.so.2）
  libjemalloc2 \
  # 🆕 新增：OpenCL 计算支持（解决 libOpenCL.so.1）
  ocl-icd-libopencl1 \
  # 🆕 新增：DRM 图形驱动
  libdrm2 \
  libdrm-intel1 \
  libdrm-nouveau2 \
  libdrm-radeon1 \
  # 🆕 新增：Mesa OpenGL 支持
  libgl1-mesa-glx \
  libgl1-mesa-dri \
  libegl1-mesa \
  libgbm1 \
  libglapi-mesa \
  libgles2-mesa \
  # 🆕 新增：音频编解码（补充）
  libflac8 \
  libspeex1 \
  libvorbis0a \
  libvorbisfile3 \
  # 🆕 新增：视频编解码（补充）
  libxvidcore4 \
  libaom3 \
  libdav1d6 \
  libheif1 \
  libjpeg62-turbo \
  libpng16-16 \
  # 🆕 新增：字幕和字体渲染
  libfreetype6 \
  libfontconfig1 \
  libfribidi0 \
  libharfbuzz0b \
  # 🆕 新增：FFmpeg 多媒体框架
  libavcodec59 \
  libavformat59 \
  libavutil57 \
  libavfilter8 \
  libswscale6 \
  libswresample4 \
  libpostproc56 \
  # 🆕 新增：网络和系统库
  libcurl4 \
  libxml2 \
  libssl3 \
  libcrypto3 \
  libzstd1 \
  liblzma5 \
  libbz2-1.0 \
  # 🆕 新增：X11 显示支持
  libx11-6 \
  libxext6 \
  libxfixes3 \
  libxi6 \
  libxrender1 \
  libxcb1 \
  libxcb-shm0 \
  libxcb-xfixes0 \
  # 🆕 新增：Wayland 显示支持
  libwayland-client0 \
  libwayland-server0 \
  libwayland-cursor0 \
  libwayland-egl1 \
  # 🆕 新增：PulseAudio 音频
  libpulse0 \
  libpulse-mainloop-glib0 \
  # 🆕 新增：ALSA 音频
  libasound2 \
  libasound2-data \
  # 🆕 新增：其他工具库
  libexpat1 \
  libgomp1 \
  libatomic1 \
  libstdc++6 \
  libgcc-s1 \
  && apt clean && rm -rf /var/lib/apt/lists/*

EXPOSE 8005

ENTRYPOINT ["/bin/bash"]

CMD ["/usr/trim/entrypoint.sh"]
