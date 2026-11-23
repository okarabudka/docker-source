#!/usr/bin/env bash
# Smoke test for the Go example image: tests/smoke-go.sh <image>
set -euo pipefail

image=${1:?usage: $0 <image>}
name="smoke-go-$$"
trap 'docker rm -f "${name}" >/dev/null 2>&1 || true' EXIT

docker run -d --name "${name}" -p 127.0.0.1::8080 "${image}" >/dev/null

for _ in $(seq 30); do
    status=$(docker inspect -f '{{.State.Health.Status}}' "${name}")
    [ "${status}" = "healthy" ] && break
    sleep 1
done
[ "${status}" = "healthy" ] || { docker logs "${name}"; echo "FAIL container is ${status}"; exit 1; }

port=$(docker port "${name}" 8080/tcp | head -n1 | cut -d: -f2)
body=$(curl -fsS "http://127.0.0.1:${port}/")
[ "${body}" = "hello from go" ] || { echo "FAIL unexpected body: ${body}"; exit 1; }

user=$(docker inspect -f '{{.Config.User}}' "${image}")
[ "${user}" = "65532:65532" ] || { echo "FAIL runs as '${user}'"; exit 1; }

echo "all checks passed"
