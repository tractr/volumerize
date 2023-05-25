FROM blacklabelops/volumerize:1.7 as megacmd-compiler

FROM alpine:3.18.0
MAINTAINER Steffen Bleul <sbl@blacklabelops.com>

ARG JOBBER_VERSION=1.4.4
ARG DOCKER_VERSION=20.10.6

COPY --from=megacmd-compiler /usr/local/bin/mega-* /usr/local/bin/
COPY --from=megacmd-compiler /usr/local/lib/libmega* /usr/local/lib/

RUN apk upgrade --update
RUN apk add \
      bash \
      tzdata \
      vim \
      tini \
      su-exec \
      gzip \
      tar \
      wget \
      curl \
      build-base \
      glib-dev \
      gmp-dev \
      asciidoc \
      curl-dev \
      tzdata \
      openssh \
      openssl \
      openssl-dev \
      duply \
      ca-certificates \
      libffi-dev \
      librsync-dev \
      gcc \
      alpine-sdk \
      linux-headers \
      musl-dev \
      rsync \
      lftp \
      py-cryptography \
      librsync \
      librsync-dev \
      python3-dev \
      duplicity \
      py3-pip
RUN pip install --upgrade pip
RUN pip install \
      setuptools \
      fasteners \
      google-api-python-client>=2.2.0 \
      PyDrive \
      chardet \
      azure-storage-blob \
      azure-storage-queue \
      boto \
      lockfile \
      paramiko \
      python-keystoneclient \
      python-swiftclient \
      requests \
      requests_oauthlib \
      urllib3 \
      b2 \
      b2sdk \
      dropbox
RUN mkdir -p /etc/volumerize /volumerize-cache /opt/volumerize

# Prepare envs for jobber and docker
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000
ARG CONTAINER_USER=jobber_client
ARG CONTAINER_GROUP=jobber_client

# Install tools
RUN apk add \
      go \
      git \
      curl \
      wget \
      make

# Install Jobber
RUN addgroup -g $CONTAINER_GID jobber_client
RUN adduser -u $CONTAINER_UID -G jobber_client -s /bin/bash -S jobber_client
RUN wget --directory-prefix=/tmp https://github.com/dshearer/jobber/releases/download/v${JOBBER_VERSION}/jobber-${JOBBER_VERSION}-r0.apk
RUN apk add --allow-untrusted --no-scripts /tmp/jobber-${JOBBER_VERSION}-r0.apk

# Install Docker CLI
RUN curl -fSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" -o /tmp/docker.tgz
ARG DOCKER_SHA="3aab01ab17734866df8b98938243f3f4c835592c"
RUN echo 'Calculated checksum: '$(sha1sum /tmp/docker.tgz)
RUN echo "$DOCKER_SHA  /tmp/docker.tgz" | sha1sum -c - && \
	  tar -xzvf /tmp/docker.tgz -C /tmp && \
	  cp /tmp/docker/docker /usr/local/bin/

# Install MEGAtools
RUN curl -fSL "https://megatools.megous.com/builds/megatools-1.10.3.tar.gz" -o /tmp/megatools.tgz
RUN tar -xzvf /tmp/megatools.tgz -C /tmp
RUN cd /tmp/megatools-1.10.3 && \
    ./configure && \
    make && \
    make install

# Install MegaCMD dependencies
RUN apk add --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing --update --no-cache \
      c-ares \
      crypto++ \
      libcurl \
      libtool \
      libuv \
      libpcrecpp \
      libsodium \
      sqlite-libs \
      sqlite \
      pcre \
      readline \
      freeimage \
      zlib

# Test MegaCMD binaries
RUN find /usr/local/bin -type f -executable -name 'mega-*' | \
      while read binary; do command -v $binary > /dev/null; done

# Cleanup
RUN apk del \
      go \
      git \
      curl \
      wget \
      python3-dev \
      libffi-dev \
      alpine-sdk \
      linux-headers \
      gcc \
      musl-dev \
      librsync-dev \
      make

RUN rm -rf /var/cache/apk/* && rm -rf /tmp/*

ENV VOLUMERIZE_HOME=/etc/volumerize \
    VOLUMERIZE_CACHE=/volumerize-cache \
    VOLUMERIZE_SCRIPT_DIR=/opt/volumerize \
    PATH=$PATH:/etc/volumerize \
    GOOGLE_DRIVE_SETTINGS=/credentials/cred.file \
    GOOGLE_DRIVE_CREDENTIAL_FILE=/credentials/googledrive.cred \
    GPG_TTY=/dev/console

USER root
WORKDIR /etc/volumerize
VOLUME ["/volumerize-cache"]
COPY imagescripts/ /opt/volumerize/
COPY scripts/ /etc/volumerize/
ENTRYPOINT ["/sbin/tini","--","/opt/volumerize/docker-entrypoint.sh"]
CMD ["volumerize"]
