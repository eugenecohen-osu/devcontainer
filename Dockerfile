# Minimal C++ development image: Ubuntu 26.04 + GCC (g++).
# GCC's libstdc++ has the most complete standard threading support
# (std::thread, std::jthread/stop_token, latch, barrier, semaphores, atomic wait).
FROM ubuntu:26.04

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        gdb \
        git \
        libblosc-dev \
        nlohmann-json3-dev \
        openssh-client \
        python3 \
        python3-pip \
        python3-venv \
        sudo \
    && rm -rf /var/lib/apt/lists/*

# Create a user matching the host UID/GID so files in the bind-mounted
# workspace keep the right ownership. Ubuntu images ship an 'ubuntu' user
# (UID 1000) and macOS's GID 20 (staff) is 'dialout' here, so reuse or
# replace existing entries rather than failing on a collision.
RUN set -eux; \
    existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
    if [ -n "${existing_user}" ]; then \
        userdel -r "${existing_user}" 2>/dev/null || userdel "${existing_user}"; \
    fi; \
    if ! getent group "${USER_GID}" >/dev/null; then \
        groupadd -g "${USER_GID}" "${USERNAME}"; \
    fi; \
    useradd -m -s /bin/bash -u "${USER_UID}" -g "${USER_GID}" "${USERNAME}"; \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"; \
    mkdir -p /workspace /data; \
    chown "${USER_UID}:${USER_GID}" /workspace /data

USER ${USERNAME}
WORKDIR /workspace

# Keep the container alive so VS Code can attach to it.
CMD ["sleep", "infinity"]
