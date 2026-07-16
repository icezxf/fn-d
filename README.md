version: '3'
services:
  trim-media:
    image: icezxf/fn-d
    container_name: fn-d
    restart: always
    network_mode: host
    volumes:
      - /home/BOCSZ/cd:/vol1/1000/media
      - /opt/1panel/apps/fn-d:/vol1/mediadata