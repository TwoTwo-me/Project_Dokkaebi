FROM node:24-bookworm-slim

ARG TARGETARCH
ARG CODEX_VERSION=0.142.2
ARG KUBECTL_VERSION=v1.33.4

LABEL org.opencontainers.image.title="Project Dokkaebi Hammer"
LABEL org.opencontainers.image.description="Dokkaebi Hammer base image with Git, GitHub CLI, Python, kubectl, and Codex."
LABEL org.opencontainers.image.source="https://github.com/TwoTwo-me/Project_Dokkaebi"

ENV HOME=/home/dokkaebi
ENV CODEX_HOME=/home/dokkaebi/.codex
ENV DOKKAEBI_LITELLM_BASE_URL=http://litellm.dokkaebi-llm.svc.cluster.local:4000
ENV PATH=/home/dokkaebi/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    less \
    openssh-client \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    tini \
  && mkdir -p -m 0755 /etc/apt/keyrings \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
  && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

RUN if [ -z "${TARGETARCH}" ]; then TARGETARCH="$(dpkg --print-architecture)"; fi \
  && case "${TARGETARCH}" in \
    amd64|arm64) kubectl_arch="${TARGETARCH}" ;; \
    *) echo "Unsupported TARGETARCH for kubectl: ${TARGETARCH}" >&2; exit 2 ;; \
  esac \
  && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${kubectl_arch}/kubectl" \
    -o /usr/local/bin/kubectl \
  && chmod 0755 /usr/local/bin/kubectl

RUN npm install -g "@openai/codex@${CODEX_VERSION}" \
  && npm cache clean --force \
  && codex --version \
  && git --version \
  && gh --version >/dev/null \
  && python3 --version \
  && kubectl version --client=true

COPY scripts/setup-codex-litellm-from-dokkaebi-key.sh /usr/local/bin/setup-codex-litellm-from-dokkaebi-key.sh
COPY images/hammer/dokkaebi-hammer-entrypoint.sh /usr/local/bin/dokkaebi-hammer-entrypoint.sh

RUN chmod 0755 /usr/local/bin/setup-codex-litellm-from-dokkaebi-key.sh /usr/local/bin/dokkaebi-hammer-entrypoint.sh \
  && mkdir -p /home/dokkaebi/.codex /workspace /tmp \
  && chown -R 1000:1000 /home/dokkaebi /workspace

WORKDIR /workspace
USER 1000:1000

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/dokkaebi-hammer-entrypoint.sh"]
CMD ["bash"]
