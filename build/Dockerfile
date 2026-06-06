FROM --platform=linux/amd64 ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8

RUN apt-get update && apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-amd64 \
    mtools \
    dosfstools \
    isolinux \
    syslinux-common \
    curl \
    wget \
    git \
    gnupg \
    ca-certificates \
    locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

COPY . /slozos
WORKDIR /slozos

VOLUME ["/output"]

CMD ["bash", "/slozos/build/build.sh"]
