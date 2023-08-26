FROM registry.access.redhat.com/ubi9/ubi-minimal@sha256:35c99977ee5baa359bdc80f9ccc360644d2dbccb7462ca0fd97a23170a00cfd1

ARG \
  QUAY_TAG_EXPIRATION=12w \
  NODEJS_VERSION=14.16.1 \
  NODEJS_SHA256SUM=068400cb9f53d195444b9260fd106f7be83af62bb187932656b68166a2f87f44 \

ENV \
  LANG='en_US.UTF-8' \
  LANGUAGE='en_US:en' \
  LC_ALL='en_US.UTF-8' \
  TZ=UTC \
  HOME=/home/default \
  USER_NAME=default  \
  USER_UID=1001 \
#   PATH="/usr/local/heroku/bin:${PATH}"

LABEL \
  org.opencontainers.image.version="v1.0" \
  org.opencontainers.image.title="HEROKU" \
  org.opencontainers.image.description="This image is used for deploying example nodejs images" \
  org.opencontainers.image.url="" \
  org.opencontainers.image.documentation="https://bitbucket.org/network-international/node-js-getting-started" \
  org.opencontainers.image.vendor="HEROKU" \
  org.opencontainers.image.licenses="Apache-2.0" \
  org.opencontainers.image.revision="${GIT_REVISION}" \
  quay.expires-after="$QUAY_TAG_EXPIRATION"

RUN set -ex && \
  #################################################################
  # Define package dependecies
  #  nss_wrapper gettext openssh-clients nano shadow-utils
  #  coreutils-single skopeo findutils rsync vim-minimal
  #################################################################
  PKGMGR='microdnf' && \
  BUILDTIME_PKGS="" && \
  RUNTIME_PKGS="shadow-utils glibc-minimal-langpack glibc-langpack-en \
  ca-certificates openssh-clients git-core tar zip findutils" && \
  #################################################################
  # Install packages --setopt=cachedir=/var/cache/dnf/f32
  #################################################################
  ${PKGMGR} \
  --disablerepo="*" \
  --enablerepo="ubi-9-appstream-rpms" \
  --enablerepo="ubi-9-baseos-rpms" \
  --enablerepo="ubi-9-codeready-builder-rpms" \
  --nodocs -y --setopt=tsflags=nodocs --setopt=install_weak_deps=0 \
  --disableplugin=subscription-manager install \
  ${BUILDTIME_PKGS} ${RUNTIME_PKGS} && \
  #################################################################
  # Cleanup packages
  #################################################################
  if [ "${BUILDTIME_PKGS}" != "" ]; then \
  ${PKGMGR} remove -y ${BUILDTIME_PKGS} \
  ;fi && \
  ${PKGMGR} clean all -y --enablerepo='*' && \
  rm -rf /{root,tmp,var/cache/{ldconfig,yum}}/* && \
  rm -rf /var/cache/* /var/log/dnf* /var/log/yum.* && \
  #################################################################
  # entrypoint script
  #################################################################
  { \
  echo '#!/bin/bash'; \
  echo '# Set current user in /etc/passwd'; \
  echo 'USER_ID=$(id -u)'; \
  echo 'GROUP_ID=$(id -g)'; \
  echo 'USER=${USER_NAME:-default}'; \
  echo 'if [ "$USER_ID" != "0" ] && [ "$USER_ID" != "1001" ]; then'; \
  echo '    if [ -w /etc/passwd ]; then'; \
  echo '        grep -v "^${USER}:" /etc/passwd >/tmp/passwd'; \
  echo '        echo "${USER}:x:$(id -u):0:${USER} user:${HOME}:/sbin/nologin" >>/tmp/passwd'; \
  echo '        cat /tmp/passwd >/etc/passwd'; \
  echo '        rm /tmp/passwd'; \
  echo '    fi'; \
  echo 'fi'; \
  echo 'exec "$@"'; \
  } > /usr/bin/entrypoint && \
  #################################################################
  # Add user and group first to make sure their IDs get assigned consistently
  ################################################################
  mkdir -p ${HOME} && \
  groupadd -r ${USER_NAME} -g ${USER_UID} && \
  useradd -l -m -u ${USER_UID} -g 0 -G wheel,root -d ${HOME} --shell /bin/bash  -c "${USER_NAME} User" ${USER_NAME} && \
  #################################################################
  # user name recognition at runtime w/ an arbitrary uid
  #################################################################
  chown -R ${USER_UID}:0 ${HOME} && \
  chgrp -R 0 ${HOME} && \
  chmod g=u ${HOME} && \
  chmod 0775 /usr/bin/entrypoint && \
  chgrp 0 /usr/bin/entrypoint && \
  chmod 0664 /etc/passwd /etc/group && \
  chmod g=u /etc/passwd /etc/group && \
  ls -la /etc/passwd && ls -la /etc/group && \
  ls -la /usr/bin/entrypoint && \
  ##################################################################
  ### Clone the Heroku package
  ##################################################################
  mkdir /app && \
  git clone --depth 1 --branch master \
  https://bitbucket.org/network-international/node-js-getting-started \
  /app  && cd /app && \
  ls -lrt && \
  #################################################################
  # install nodejs
  #################################################################
  curl --progress-bar --location --fail --show-error \
  --connect-timeout "${CURL_CONNECTION_TIMEOUT:-20}" \
  --retry "${CURL_RETRY:-5}" \
  --retry-delay "${CURL_RETRY_DELAY:-0}" \
  --retry-max-time "${CURL_RETRY_MAX_TIME:-60}" \
  --output /tmp/node-v${NODEJS_VERSION}-linux-x64.tar.gz \
  https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.gz && \
  echo "${NODEJS_SHA256SUM} /tmp/node-v${NODEJS_VERSION}-linux-x64.tar.gz" | sha256sum -c - && \
  tar -xzf /tmp/node-v${NODEJS_VERSION}-linux-x64.tar.gz -C /usr/local \
  --strip-components=1 --no-same-owner --no-wildcards-match-slash --anchored \
  --exclude */CHANGELOG.md --exclude */LICENSE --exclude */README.md --exclude share && \
  rm -rf /tmp/node-v${NODEJS_VERSION}-linux-x64.tar.gz && \
  ln -s /usr/local/bin/node /usr/local/bin/nodejs && \
  mkdir -p ${HOME}/.npm-global/{lib,bin} && \
  npm config --global set update-notifier false && \
  npm config --global set prefix ${HOME}/.npm-global && \
  npm install -g npm@latest yarn@1.22.19 && \
  node --version && \
  npm --version && \
  ##################################################################
  ### install Heroku cli
  ##################################################################
  curl https://cli-assets.heroku.com/install.sh | sh && \
  #################################################################
  ## finalize
  #################################################################
  chown -R ${USER_UID}:0 ${HOME} /etc/passwd /etc/group && \
  chmod -R 0775 ${HOME} /etc/passwd /etc/group && \
  rm -rf /{root,tmp,var/cache/{ldconfig,yum}}/* && \
  rm -rf /var/cache/* /var/log/dnf* /var/log/yum.* && \
  #################################################################
  ## app specific configuration
  #################################################################
   npm install --production
   WORKDIR /app

   # Expose port 8080 for the app to listen on
    EXPOSE 8080

   ### Containers should not run as root as a good practice 
   USER 1001

   # Start the app
   CMD ["npm", "start"]
