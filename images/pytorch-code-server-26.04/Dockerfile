FROM nvcr.io/nvidia/pytorch:26.04-py3

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        openssh-server \
        sudo \
    && curl -fsSL https://code-server.dev/install.sh | sh \
    && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu \
    && mkdir -p /run/sshd /home/jovyan/.config/code-server \
    && chown -R ubuntu:ubuntu /home/jovyan \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY start-code-server.sh /usr/local/bin/start-code-server
RUN chmod +x /usr/local/bin/start-code-server

ENV DEFAULT_WORKSPACE=/home/jovyan
ENV APP_USER=ubuntu
EXPOSE 8888 22

CMD ["/usr/local/bin/start-code-server"]

