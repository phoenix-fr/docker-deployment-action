#!/bin/sh
set -eu

if [ -z "$INPUT_REMOTE_DOCKER_PORT" ]; then
  INPUT_REMOTE_DOCKER_PORT=22
fi

if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
    echo "Input remote_docker_host is required!"
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

if [ -z "$INPUT_STACK_FILE_NAME" ]; then
  INPUT_STACK_FILE_NAME=docker-compose.yml
fi

if [ -z "$INPUT_GH_TOKEN" ]; then
    echo "Input github token is required!"
    exit 1
fi

if [ -z "$INPUT_DEPLOY_PATH" ]; then
  INPUT_DEPLOY_PATH="~/.deploy"
fi

STACK_FILE=${INPUT_STACK_FILE_NAME}

echo "Registering SSH keys..."

# register the private key with the agent.
mkdir -p "$HOME/.ssh"
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > "$HOME/.ssh/id_rsa"
chmod 600 "$HOME/.ssh/id_rsa"
eval $(ssh-agent)
ssh-add "$HOME/.ssh/id_rsa"

echo "Add to known host"
ssh -oStrictHostKeyChecking=accept-new -p$INPUT_REMOTE_DOCKER_PORT $INPUT_REMOTE_DOCKER_HOST "echo \"SSH OK\""

STACK_FULL_PATH=$INPUT_DEPLOY_PATH/${INPUT_ARGS}/$STACK_FILE
STACK_DIR=`dirname $STACK_FULL_PATH`
LOG_DIR="$INPUT_DEPLOY_PATH/../logs/${INPUT_ARGS}"

echo "Create deploy dir"
ssh -p$INPUT_REMOTE_DOCKER_PORT $INPUT_REMOTE_DOCKER_HOST "mkdir -p $STACK_DIR" 
ssh -p$INPUT_REMOTE_DOCKER_PORT $INPUT_REMOTE_DOCKER_HOST "mkdir -p $LOG_DIR"

echo "Copy stack yml file"
scp -P$INPUT_REMOTE_DOCKER_PORT $STACK_FILE $INPUT_REMOTE_DOCKER_HOST:$STACK_FULL_PATH

DEPLOYMENT_COMMAND="docker stack deploy --with-registry-auth -c $STACK_FULL_PATH ${INPUT_ARGS}"
echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: ${DEPLOYMENT_COMMAND}"

ssh -p$INPUT_REMOTE_DOCKER_PORT $INPUT_REMOTE_DOCKER_HOST "echo $INPUT_GH_TOKEN | docker login ghcr.io -u USERNAME --password-stdin && ${DEPLOYMENT_COMMAND}" 2>&1
