ARG BUILD_FROM
FROM $BUILD_FROM

ENV TZ=Asia/Seoul LANG=C.UTF-8 LC_ALL=C.UTF-8
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl git gnupg jq openssh-client openssh-server sudo tzdata zsh && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd

COPY run.sh /run.sh
RUN chmod 755 /run.sh
EXPOSE 2322
CMD ["/run.sh"]
