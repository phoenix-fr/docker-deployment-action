#!/bin/sh
set -eu

if [ -z "$INPUT_REMOTE_DOCKER_PORT" ]; then
  INPUT_REMOTE_DOCKER_PORT=22
fi

if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
    echo "Input remote_docker_host is required!"
    exit 1
fi

if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
    echo "Input ssh_public_key is required!"
    exit 1
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
    echo "Input ssh_private_key is required!"
    exit 1
fi

if [ -z "$INPUT_ARGS" ]; then
  echo "Input input_args is required!"
  exit 1
fi

if [ -z "$INPUT_DEPLOY_PATH" ]; then
  INPUT_DEPLOY_PATH=~/docker-deployment
fi

if [ -z "$INPUT_STACK_FILE_NAME" ]; then
  INPUT_STACK_FILE_NAME=docker-compose.yaml
fi

if [ -z "$INPUT_DEPLOY_PATH" ]; then
  INPUT_DEPLOY_PATH=~/.deploy
fi

if [ -z "$INPUT_TRAEFIK_FILE_NAME" ]; then
  DEPLOY_OPTION=" -c $INPUT_DEPLOY_PATH/$INPUT_TRAEFIK_FILE_NAME"
fi

STACK_FILE=${INPUT_STACK_FILE_NAME}
DEPLOYMENT_COMMAND="docker stack deploy --with-registry-auth $DEPLOY_OPTION -c $INPUT_DEPLOY_PATH/$STACK_FILE"

echo "Registering SSH keys..."

# register the private key with the agent.
mkdir -p "$HOME/.ssh"
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > "$HOME/.ssh/id_rsa"
chmod 600 "$HOME/.ssh/id_rsa"
eval $(ssh-agent)
ssh-add "$HOME/.ssh/id_rsa"

echo "Add to known host"
ssh -oStrictHostKeyChecking=accept-new -p$INPUT_REMOTE_DOCKER_PORT $INPUT_REMOTE_DOCKER_HOST "echo \"SSH OK\""

echo "Copy yml files"
scp -P$INPUT_REMOTE_DOCKER_PORT $STACK_FILE $INPUT_REMOTE_DOCKER_HOST:$INPUT_DEPLOY_PATH/

if [ -z "$INPUT_TRAEFIK_FILE_NAME" ]; then
  scp -P$INPUT_REMOTE_DOCKER_PORT $INPUT_TRAEFIK_FILE_NAME $INPUT_REMOTE_DOCKER_HOST:$INPUT_DEPLOY_PATH/
fi

echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: ${DEPLOYMENT_COMMAND} ${INPUT_ARGS}"

ssh -p$INPUT_REMOTE_DOCKER_PORT $INPUT_REMOTE_DOCKER_HOST "echo $GH_TOKEN | | docker login ghcr.io -u USERNAME --password-stdin && ${DEPLOYMENT_COMMAND} ${INPUT_ARGS}" 2>&1
