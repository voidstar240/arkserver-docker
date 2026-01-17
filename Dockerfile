FROM gcc:latest AS builder

WORKDIR /build
COPY ./rcon.c ./rcon.c
RUN gcc -O3 -o rcon rcon.c

FROM ubuntu:latest

# delete default ubuntu user
RUN touch /var/mail/ubuntu \
    && chown ubuntu /var/mail/ubuntu \
    && userdel -r ubuntu

# dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        bash \
        build-essential \
        ca-certificates \
        curl \
        gosu \
        lib32gcc-s1 \
        libcap2-bin \
        locales \
        sudo \
        tcpdump \
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# gen locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# add appuser
# uid and gid will be updated to $UID and $GID by entrypoint.sh
RUN groupadd -g 1000 appgroup \
    && useradd -u 1000 -g appgroup -m appuser \
    && echo "appuser ALL=NOPASSWD: /usr/bin/tcpdump" > /etc/sudoers.d/10-tcpdump-appuser

COPY --from=builder /build/rcon /usr/bin/rcon

ENV SERVER_NAME="ARKServer" \
    MAP_NAME="TheIsland" \
    SERVER_PASSWORD="" \
    ADMIN_PASSWORD="admin_password" \
    SERVER_APPID="376030" \
    SERVER_BRANCH="" \
    SERVER_NO_STEAM="" \
    UPDATE_SERVER="" \
    UID="" \
    GID=""

EXPOSE 7777/udp
EXPOSE 7778/udp
EXPOSE 27015/udp
EXPOSE 27020/tcp

VOLUME ["/data"]

COPY entrypoint.sh /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s \
    CMD pgrep "ShooterGame" > /dev/null || pgrep "steamcmd" > /dev/null || exit 1

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
CMD ["/bin/bash", "/data/start.sh"]
