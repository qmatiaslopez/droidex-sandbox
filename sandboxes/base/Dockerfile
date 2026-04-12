FROM debian:bookworm-slim

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV FACTORY_USER_HOME=/home/${USERNAME}
ENV PATH="/usr/local/bin:${FACTORY_USER_HOME}/.local/bin:${FACTORY_USER_HOME}/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    less \
    procps \
    openssh-client \
    sudo \
    xdg-utils \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
 && mkdir -p /workspace ${FACTORY_USER_HOME}/.factory ${FACTORY_USER_HOME}/.cache ${FACTORY_USER_HOME}/.local/bin \
 && chown -R ${USERNAME}:${USERNAME} /workspace ${FACTORY_USER_HOME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

WORKDIR /workspace

RUN curl -fsSL https://app.factory.ai/cli | sh \
 && install -m 0755 /root/.local/bin/droid /usr/local/bin/droid

CMD ["bash"]
