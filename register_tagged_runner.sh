#!/bin/bash

set -e

# Variables
RUNNER_NAME=${1}
REGISTER_TOKEN=${2}
RUNNER_TAGS=${3}
CI_SERVER_URL=${4:-"https://gitlab.com/ci"}
CONFIG_PATH=config/config.toml

if [[ -z "$2" ]]
then
    echo "Usage: register_runner.sh RUNNER_NAME REGISTER_TOKEN CI_SERVER_URL"
    echo "If CI_SERVER_URL is left empty, https://gitlab.com/ci is assumed"
    exit 1
fi

if [[ -f "${CONFIG_PATH}" ]]
then
    RE="\\[\\[runners\\]\\]"
    RE="${RE}[^\\[]*"
    RE="${RE}name = \\\"${RUNNER_NAME}\\\""
    RE="${RE}[^\\[]*"
    RE="${RE}url = \\\"${CI_SERVER_URL}\\\""
    RE="${RE}[^\\[]*"
    RE="${RE}token = \\\"([^\\\"]*)\\\""
    RE="${RE}[^\\[]*"

    if [[ $(cat "${CONFIG_PATH}") =~ ${RE} ]]
    then
        echo "The runner \"${RUNNER_NAME}\" already exists."
        exit 1
    fi
fi

docker-compose exec -T runner \
    gitlab-runner \
    register \
    --non-interactive \
    --url "${CI_SERVER_URL}" \
    --name "${RUNNER_NAME}" \
    --registration-token "${REGISTER_TOKEN}" \
    --cache-dir /cache \
    --builds-dir /builds \
    --executor docker \
    --docker-host tcp://host.docker:2375 \
    --docker-image alpine:3.8 \
    --docker-privileged \
    --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
    --docker-volumes /cache:/cache \
    --docker-volumes /builds:/builds \
    --tag-list "${RUNNER_TAGS}" \
    --run-untagged="false" \
