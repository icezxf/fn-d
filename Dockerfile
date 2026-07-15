FROM debian:12.12 AS builder

# 定义下载链接变量
ARG ISO_URL="https://iso.liveupdate.fnnas.com/arm/trim/1.1.31/armsr/fnos_Mainland-PE_arm_1.1.31_armsr_1366.iso?sign=a7da1f6db7330995780bd939e93c3b91&t=1784081809"
ARG MEDIA_TAR_URL="https://github.com/icezxf/fn-d/releases/download/1/trim.media.tar.gz"

COPY fakebroker.go ./fakebroker.go
COPY init.sql ./init.sql
COPY entrypoint.sh ./entrypoint.sh

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
  apt update && apt install -y p7zip-full curl wget ca-certificates && \
  # 下载 fnos.iso
  echo "Downloading fnos.iso..." && \
  wget --no-check-certificate --timeout=30 --tries=5 -O fnos.iso "${ISO_URL}" || \
  curl --insecure --retry 5 --retry-delay 10 -L -o fnos.iso "${ISO_URL}" && \
  ls -lh fnos.iso && \
  # 解压ISO
  7z x fnos.iso -ofniso && \
  cd /fniso && tar -xvf trimfs.tgz --strip-components=1 ./usr/trim/bin/mediasrv ./usr/trim/lib/libnebula.so ./usr/trim/lib/libppjson.so ./usr/trim/lib/mediasrv && \
  mkdir -p /fniso/usr/trim/etc && mv /entrypoint.sh /init.sql /fniso/usr/trim/ && \
  # 下载 trim.media.tar.gz 到 builder 的根目录
  echo "Downloading trim.media.tar.gz..." && \
  wget --no-check-certificate --timeout=30 --tries=5 -O /trim.media.tar.gz "${MEDIA_TAR_URL}" || \
  curl --insecure --retry 5 --retry-delay 10 -L -o /trim.media.tar.gz "${MEDIA_TAR_URL}" && \
  ls -lh /trim.media.tar.gz && \
  if [ ! -s /trim.media.tar.gz ]; then echo "Download failed: file is empty"; exit 1; fi && \
  # 编译 fakebroker
  GOPKG=go1.24.10.linux-arm64 && \
  curl -O https://dl.google.com/go/${GOPKG}.tar.gz && \
  tar -C /opt -xvf ${GOPKG}.tar.gz && \
  GOARCH=arm64 /opt/go/bin/go build -o /fniso/usr/trim/bin/rpcbroker /fakebroker.go && \
  # 清理临时文件（保留 /trim.media.tar.gz 给 final 阶段使用）
  rm -f fnos.iso ${GOPKG}.tar.gz

FROM --platform=linux/arm64 debian:12.12

ENV LD_LIBRARY_PATH=/usr/trim/lib/mediasrv LOG_LEVEL=info MEDIA_DIRS=/vol1/1000/media

COPY --from=builder /fniso/usr/trim /usr/trim
# 从 builder 复制下载好的 trim.media.tar.gz
COPY --from=builder /trim.media.tar.gz /tmp/trim.media.tar.gz
# 使用 ADD 解压到目标目录
ADD /tmp/trim.media.tar.gz /usr/local/apps/@appcenter/

WORKDIR /usr/trim

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
  apt update && apt install -y sqlite3 openssl ca-certificates libass9 libbluray2 libmp3lame0 \
  libopenmpt0 libopus0 libtcmalloc-minimal4 libtheora0 libvorbisenc2 libvpx7 libwebp7 \
  libwebpmux3 libx264-164 libx265-199 libzvbi0 && apt clean && rm -rf /var/lib/apt/lists/*

EXPOSE 8005

ENTRYPOINT ["/bin/bash"]

CMD ["/usr/trim/entrypoint.sh"]
