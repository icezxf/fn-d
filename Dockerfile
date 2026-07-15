FROM debian:12.12 AS builder

# 所有文件都从构建上下文复制（由 GitHub Actions 提前下载好）
COPY fnos.iso ./fnos.iso
COPY trim.media.tar.gz /tmp/trim.media.tar.gz
COPY fakebroker.go ./fakebroker.go
COPY init.sql ./init.sql
COPY entrypoint.sh ./entrypoint.sh

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
  apt update && apt install -y p7zip-full curl && \
  # 解压ISO
  7z x fnos.iso -ofniso && \
  # ★★★ 关键修复：cd /fniso 并使用 --strip-components=1 ★★★
  cd /fniso && tar -xvf trimfs.tgz --strip-components=1 ./usr/trim/bin/mediasrv ./usr/trim/lib/libnebula.so ./usr/trim/lib/libppjson.so ./usr/trim/lib/mediasrv && \
  mkdir -p /fniso/usr/trim/etc && \
  mv /entrypoint.sh /init.sql /fniso/usr/trim/ && \
  # 解压 trim.media.tar.gz
  mkdir -p /fniso/usr/local/apps/@appcenter/ && \
  tar -xzf /tmp/trim.media.tar.gz -C /fniso/usr/local/apps/@appcenter/ && \
  chmod -R 755 /fniso/usr/local/apps/@appcenter/trim.media/ && \
  # 编译 fakebroker（ARM64）
  GOPKG=go1.24.10.linux-arm64 && \
  curl -O https://dl.google.com/go/${GOPKG}.tar.gz && \
  tar -C /opt -xvf ${GOPKG}.tar.gz && \
  GOARCH=arm64 /opt/go/bin/go build -o /fniso/usr/trim/bin/rpcbroker fakebroker.go && \
  # 清理临时文件
  rm -f fnos.iso /tmp/trim.media.tar.gz ${GOPKG}.tar.gz

# ======  final stage   ======
FROM --platform=linux/arm64 debian:12.12

ENV LD_LIBRARY_PATH=/usr/trim/lib/mediasrv LOG_LEVEL=info MEDIA_DIRS=/vol1/1000/media

COPY --from=builder /fniso/usr/trim /usr/trim
COPY --from=builder /fniso/usr/local/apps/@appcenter /usr/local/apps/@appcenter

WORKDIR /usr/trim

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
  apt update && apt install -y sqlite3 openssl ca-certificates libass9 libbluray2 libmp3lame0 \
  libopenmpt0 libopus0 libtcmalloc-minimal4 libtheora0 libvorbisenc2 libvpx7 libwebp7 \
  libwebpmux3 libx264-164 libx265-199 libzvbi0 && apt clean && rm -rf /var/lib/apt/lists/*

EXPOSE 8005

ENTRYPOINT ["/bin/bash"]

CMD ["/usr/trim/entrypoint.sh"]
