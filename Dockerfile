FROM debian:12.12 AS builder

COPY ./fnos.iso ./fnos.iso
COPY fakebroker.go ./fakebroker.go
COPY init.sql ./init.sql
COPY entrypoint.sh ./entrypoint.sh
COPY manifest ./manifest

RUN apt update && apt install -y p7zip-full curl && 7z x fnos.iso -ofniso && \
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

# 安装最小必需依赖（使用官方源）
RUN apt update && apt install -y \
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
  libva2 \
  libva-drm2 \
  libjemalloc2 \
  ocl-icd-libopencl1 \
  libdrm2 \
  libgl1-mesa-glx \
  libgl1-mesa-dri \
  libegl1-mesa \
  libgbm1 \
  libglapi-mesa \
  libgles2-mesa \
  libcurl4 \
  libxml2 \
  libssl3 \
  && apt clean && rm -rf /var/lib/apt/lists/*

EXPOSE 8005

ENTRYPOINT ["/bin/bash"]

CMD ["/usr/trim/entrypoint.sh"]