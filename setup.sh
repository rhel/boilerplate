#!/usr/bin/env bash

set -euf -o pipefail

dockerArgs="
  --detach
  --log-opt max-file=5
  --log-opt max-size=10m
  --restart unless-stopped
"
jenkinsTagVersion=$(date "+%F")
timeout=300

errx() {
  echo "$*"
  exit 1
}

off() {
  case $1 in
    stdout)
      exec 6>&1
      exec > /dev/null
      ;;
    stderr)
      exec 7>&2
      exec 2>/dev/null
      ;;
  esac
}

on() {
  case $1 in
    stdout)
      exec 1>&6 6>&-
      ;;
    stderr)
      exec 2>&7 7>&-
      ;;
  esac
}

case "$(uname)" in
  Linux)
    ;;
  *)
    errx "ERROR: $(uname) is not supported OS."
    ;;
esac

SCRIPT_ROOT=$(dirname "$(readlink -f $0)")

sudo apt-get update
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  netcat-openbsd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/docker.list
deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable
EOF
sudo apt-get update
sudo apt-get install -y \
  containerd.io \
  docker-ce \
  docker-ce-cli

off stdout
off stderr

for container in jenkins consul-client consul-server; do
  sudo docker stop $container || :
  sudo docker rm $container || :
done

sudo docker volume rm jenkins-home || :

for port in 80 8500; do
  if nc -vz localhost $port; then
    on stderr
    >&2 echo "ERROR: the port $port/tcp is already in use."
    exit 1
  fi
done

if nc -uvz localhost 8600; then
  on stderr
  >&2 echo "ERROR: the port 8600/udp is already in use."
  exit 1
fi

on stderr
on stdout

sudo docker build \
  --build-arg DOCKER_GID=$(stat -c %g /var/run/docker.sock) \
  --tag jenkins:$jenkinsTagVersion \
  "$SCRIPT_ROOT/jenkins"

off stdout

sudo docker run \
  $dockerArgs \
  --publish 8500:8500 \
  --publish 8600:8600/udp \
  --name=consul-server \
  consul agent -server -ui -node=server -bootstrap-expect=1 -client=0.0.0.0

consulHttpAddr=$(
  sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' consul-server
)

sudo docker run \
  $dockerArgs \
  --name=consul-client \
  consul agent -node=client -join=$consulHttpAddr

sudo docker volume create jenkins-home
sudo docker run \
  $dockerArgs \
  --name jenkins \
  --publish 80:8080 \
  --volume $(which docker):/usr/bin/docker:ro \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume jenkins-home:/var/jenkins_home \
  jenkins:$jenkinsTagVersion

on stdout

echo -n "wait for jenkins: "
for i in `seq ${timeout}`; do
  status=$(sudo docker inspect -f "{{ .State.Health.Status }}" jenkins)
  if [ x"$status" = x"healthy" ]; then
    echo ok
    exit 0
  else
    echo -n .
    sleep 1
  fi
done

echo fail
exit 1
