FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install SSH, sudo, Python + dependencies (pip, venv, dev)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd /data/shared /keys

# Build args
ARG SSH_PORT=22

EXPOSE $SSH_PORT

# Define Volumes
# /keys: Stores generated SSH keys persistently
# /data/shared: Shared data volume
# /home: Persist user directories (optional, but good for retaining .bash_history etc)
VOLUME ["/data/shared", "/keys"]

# Copy helper scripts
COPY gen_ssh_keys.sh /usr/local/bin/gen_ssh_keys.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/gen_ssh_keys.sh /usr/local/bin/entrypoint.sh

CMD ["/usr/local/bin/entrypoint.sh"]
