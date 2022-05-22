FROM debian:bullseye-slim

ENV ENV_NAME=""
ENV GITHUB_PAT=""
ENV GITHUB_TOKEN=""
ENV RUNNER_NAME="git_runner"
ENV GITHUB_OWNER="shekhar-jha"
ENV GITHUB_REPOSITORY="base-demo"
ENV RUNNER_WORKDIR="_work"
ENV RUNNER_LABELS=""
ENV ADDITIONAL_PACKAGES=""

RUN apt-get update \
  && apt-get install -y \
     curl \
     sudo \
     git \
     jq  \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && useradd -m github \
  && usermod -aG sudo github \
  && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
  && mkdir -p /opt/github \
  && chown github:github /opt/github

USER github
WORKDIR /opt/github

RUN GITHUB_RUNNER_VERSION=$(curl --silent "https://api.github.com/repos/actions/runner/releases/latest" | jq -r '.tag_name[1:]') \
    && curl -Ls https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-linux-x64-${GITHUB_RUNNER_VERSION}.tar.gz | tar xz \
    && sudo ./bin/installdependencies.sh

COPY --chown=github:github entrypoint.sh ./
RUN sudo chmod u+x ./entrypoint.sh

ENTRYPOINT ["/opt/github/entrypoint.sh"]
