FROM debian:12.12 AS builder

# 定义下载链接变量
ARG ISO_URL="https://iso.liveupdate.fnnas.com/arm/trim/1.1.31/armsr/fnos_Mainland-PE_arm_1.1.31_armsr_1366.iso?sign=a7da1f6db7330995780bd939e93c3b91&t=1784081809"
ARG MEDIA_TAR_URL="https://github.com/icezxf/fn-d/releases/download/1/trim.media.tar.gz"

# 复制所有必要的文件
COPY fakebroker.go ./fakebroker.go
COPY init.sql ./init.sql
COPY entrypoint.sh ./entrypoint.sh
COPY mainfest ./mainfest  # <--- 新增：复制 mainfest 文件

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
  apt update && apt install -y p7zip-full curl wget ca-certificates && \
  # 下载ISO文件
  echo "Downloading ISO file..." && \
  wget --no-check-certificate --timeout=30 --tries=5 -O fnos.iso "${ISO_URL}" || \
  curl --insecure --retry 5 --retry-delay 10 -L -o fnos.iso "${ISO_URL}" && \
  ls -lh fnos.iso && \
  # 解压ISO
  7z x fnos.iso -ofniso && \
  cd /fniso && tar -xvf trimfs.tgz --strip-components=1 ./usr/trim/bin/mediasrv ./usr/trim/lib/libnebula.so ./usr/trim/lib/libppjson.so ./usr/trim/lib/mediasrv && \
  mkdir -p /fniso/usr/trim/etc && mv /entrypoint.sh /init.sql /fniso/usr/trim/ && \
  # 下载trim.media.tar.gz (从GitHub Release)
  echo "Downloading trim.media.tar.gz from GitHub Release..." && \
  wget --no-check-certificate --timeout=30 --tries=5 -O /tmp/trim.media.tar.gz "${MEDIA_TAR_URL}" || \
  curl --insecure --retry 5 --retry-delay 10 -L -o /tmp/trim.media.tar.gz "${MEDIA_TAR_URL}" && \
  ls -lh /tmp/trim.media.tar.gz && \
  # 验证下载是否成功
  if [ ! -s /tmp/trim.media.tar.gz ]; then echo "Download failed: file is empty"; exit 1; fi && \
  mkdir -p /fniso/usr/local/apps/@appcenter/ && \
  tar -xzf /tmp/trim.media.tar.gz -C /fniso/usr/local/apps/@appcenter/ && \
  # 安装Go并编译fakebroker
  GOPKG=go1.24.10.linux-arm64 && \
  curl -O https://dl.google.com/go/${GOPKG}.tar.gz && \
  tar -C /opt -xvf ${GOPKG}.tar.gz && \
  GOARCH=arm64 /opt/go/bin/go build -o /fniso/usr/trim/bin/rpcbroker /fakebroker.go && \
  # 清理临时文件
  rm -f fnos.iso /tmp/trim.media.tar.gz ${GOPKG}.tar.gz

FROM --platform=linux/arm64 debian:12.12

ENV LD_LIBRARY_PATH=/usr/trim/lib/mediasrv LOG_LEVEL=info MEDIA_DIRS=/vol1/1000/media

# 从builder复制构建产物
COPY --from=builder /fniso/usr/trim /usr/trim
COPY --from=builder /fniso/usr/local/apps/@appcenter /usr/local/apps/@appcenter

# --- 新增：创建目标目录并复制 mainfest 文件 ---
RUN mkdir -p /var/apps/trim.media/
COPY --from=builder /mainfest /var/apps/trim.media/mainfest

WORKDIR /usr/trim

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
  apt update && apt install -y sqlite3 openssl ca-certificates libass9 libbluray2 libmp3lame0 \
  libopenmpt0 libopus0 libtcmalloc-minimal4 libtheora0 libvorbisenc2 libvpx7 libwebp7 \
  libwebpmux3 libx264-164 libx265-199 libzvbi0 && apt clean && rm -rf /var/lib/apt/lists/*

EXPOSE 8005

ENTRYPOINT ["/bin/bash"]

CMD ["/usr/trim/entrypoint.sh"]
