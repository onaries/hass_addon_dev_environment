#!/usr/bin/env bash
set -euo pipefail

image=${1:-local/hass-ssh-docker:codex-test}
name="hass-ssh-smoke-$$"
volume="hass-ssh-data-$$"
fixture=$(mktemp -d)
cleanup() {
    docker rm -f "$name" >/dev/null 2>&1 || true
    docker volume rm "$volume" >/dev/null 2>&1 || true
    rm -rf "$fixture"
}
trap cleanup EXIT

ssh-keygen -q -t ed25519 -N '' -f "$fixture/client"
docker volume create "$volume" >/dev/null
docker run --rm --entrypoint sh -v "$volume:/data" -e TEST_KEY="$(cat "$fixture/client.pub")" "$image" -c \
    'jq -n --arg key "$TEST_KEY" "{ssh_keys: [\$key]}" > /data/options.json; mkdir -p /data/openclaw_config; touch /data/openclaw_config/preserved'
docker run -d --name "$name" -p 127.0.0.1::2322 -v "$volume:/data" \
    -v /var/run/docker.sock:/var/run/docker.sock "$image" >/dev/null

for _ in $(seq 1 30); do
    if docker logs "$name" 2>&1 | grep -q 'Server listening on'; then break; fi
    if [ "$(docker inspect -f '{{.State.Running}}' "$name")" != true ]; then docker logs "$name"; exit 1; fi
    sleep 1
done
port=$(docker port "$name" 2322/tcp | sed 's/.*://')
ssh_args=(-F /dev/null -i "$fixture/client" -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new -o HostKeyAlias=hass-smoke -o "UserKnownHostsFile=$fixture/known_hosts")
ssh "${ssh_args[@]}" -p "$port" developer@127.0.0.1 'docker version --format "{{.Server.Version}}" && docker compose version && test -d /workspace'
listeners=$(docker logs "$name" 2>&1 | grep -c 'Server listening on')
docker restart "$name" >/dev/null
port=$(docker port "$name" 2322/tcp | sed 's/.*://')
for _ in $(seq 1 30); do
    current=$(docker logs "$name" 2>&1 | grep -c 'Server listening on' || true)
    if [ "$current" -gt "$listeners" ]; then break; fi
    if [ "$(docker inspect -f '{{.State.Running}}' "$name")" != true ]; then docker logs "$name"; exit 1; fi
    sleep 1
done
ssh "${ssh_args[@]}" -p "$port" developer@127.0.0.1 'test -e /data/openclaw_config/preserved && docker version --format "{{.Server.Version}}"'
printf '%s\n' 'SSH login, Docker access, restart, host key and existing data: PASS'
