FROM jenkins/jenkins:lts

ARG DOCKER_GID=998
ENV JENKINS_HOME_URL=https://s3-boilerplate.s3.amazonaws.com/jenkins-home.tar.gz
ENV JENKINS_HOME_SHA256=3ea0215cfea417d24c002da2a6dd2b088a3dcade3be91850aca39830c51c6bcc

USER root
RUN set -x \
    && groupadd -g "$DOCKER_GID" docker \
    && gpasswd -a jenkins docker
USER jenkins

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

HEALTHCHECK --interval=20s --retries=10 --timeout=30s \
  CMD curl -f http://localhost:8080/ || exit 1
ENTRYPOINT [ "docker-entrypoint.sh" ]

# vim:set syntax=dockerfile:
