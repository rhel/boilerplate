#!/usr/bin/env bash

set -euf -o pipefail

if [ ! -f "$JENKINS_HOME/config.xml" ]; then
  tmpfile=$(mktemp)
  trap "{ rm -f $tmpfile; }" EXIT INT TERM

  curl -SL "$JENKINS_HOME_URL" -o $tmpfile
  echo "$JENKINS_HOME_SHA256 $tmpfile" | sha256sum --check

  tar xvf $tmpfile -C "$JENKINS_HOME"
fi

exec "/usr/local/bin/jenkins.sh"
