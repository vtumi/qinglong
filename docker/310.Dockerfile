FROM node:22-slim AS nodebuilder

FROM python:3.10-slim-bookworm AS builder
COPY . /tmp/build
COPY --from=nodebuilder /usr/local/bin/node /usr/local/bin/
COPY --from=nodebuilder /usr/local/lib/node_modules/. /usr/local/lib/node_modules/
RUN set -x && \
  ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
  apt-get update && \
  apt-get install --no-install-recommends -y libatomic1 && \
  npm i -g pnpm@8.3.1 && \
  cd /tmp/build && \
  pnpm --registry https://registry.npmmirror.com install && \
  pnpm run build:front && \
  pnpm run build:back

FROM python:3.10-slim-bookworm

ARG QL_MAINTAINER="whyour"
LABEL maintainer="${QL_MAINTAINER}"
ARG QL_URL=https://github.com/${QL_MAINTAINER}/qinglong.git
ARG QL_BRANCH=develop
ARG PYTHON_SHORT_VERSION=3.10

ENV QL_DIR=/ql \
  QL_BRANCH=${QL_BRANCH} \
  LANG=C.UTF-8 \
  SHELL=/bin/bash \
  PS1="\u@\h:\w \$ "

COPY --from=nodebuilder /usr/local/bin/node /usr/local/bin/
COPY --from=nodebuilder /usr/local/lib/node_modules/. /usr/local/lib/node_modules/
COPY . ${QL_DIR}

WORKDIR ${QL_DIR}

RUN set -x && \
  ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
  apt-get update && \
  apt-get upgrade -y && \
  apt-get install --no-install-recommends -y git \
  curl \
  wget \
  tzdata \
  perl \
  openssl \
  openssh-client \
  nginx \
  jq \
  procps \
  netcat-openbsd \
  unzip \
  libatomic1 && \
  apt-get clean && \
  ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
  echo "Asia/Shanghai" >/etc/timezone && \
  git config --global user.email "qinglong@users.noreply.github.com" && \
  git config --global user.name "qinglong" && \
  git config --global http.postBuffer 524288000 && \
  npm install -g pnpm@8.3.1 pm2 tsx && \
  pnpm config set registry https://registry.npmmirror.com && \
  pnpm install --prod && \
  rm -rf /root/.cache && \
  rm -rf /root/.npm && \
  rm -rf /etc/apt/apt.conf.d/docker-clean && \
  ulimit -c 0

ENV PNPM_HOME=${QL_DIR}/data/dep_cache/node \
  PYTHON_HOME=${QL_DIR}/data/dep_cache/python3 \
  PYTHONUSERBASE=${QL_DIR}/data/dep_cache/python3

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PNPM_HOME}:${PYTHON_HOME}/bin \
  NODE_PATH=/usr/local/bin:/usr/local/lib/node_modules:${PNPM_HOME}/global/5/node_modules \
  PIP_CACHE_DIR=${PYTHON_HOME}/pip \
  PYTHONPATH=${PYTHON_HOME}:${PYTHON_HOME}/lib/python${PYTHON_SHORT_VERSION}:${PYTHON_HOME}/lib/python${PYTHON_SHORT_VERSION}/site-packages

RUN pip3 install --prefix ${PYTHON_HOME} requests

RUN cp -f .env.example .env && \
  chmod +x ${QL_DIR}/shell/*.sh && \
  chmod +x ${QL_DIR}/docker/*.sh && \
  mkdir -p ${QL_DIR}/static

COPY --from=builder /tmp/build/static ${QL_DIR}/static

HEALTHCHECK --interval=5s --timeout=2s --retries=20 \
  CMD curl -sf --noproxy '*' http://127.0.0.1:5600/api/health || exit 1

ENTRYPOINT ["./docker/docker-entrypoint.sh"]

VOLUME /ql/data
  
EXPOSE 5700
