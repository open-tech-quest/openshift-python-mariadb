#!/usr/bin/env bash
# Build and push the multi-arch (amd64 + arm64) app image with Podman.
# Usage: ./build.sh            -> builds & pushes :<timestamp> and :latest
#        PUSH=false ./build.sh -> build only
set -euo pipefail

REPOSITORY="${REPOSITORY:-quay.io/open-tech-quest/openshift-python-mariadb-app}"
VERSION="${VERSION:-$(date +%Y%m%d%H%M)}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
PUSH="${PUSH:-true}"

IMAGE="${REPOSITORY}:${VERSION}"
cd "$(dirname "$0")"

echo "Build ${IMAGE} for ${PLATFORMS}"
podman manifest rm "${IMAGE}" 2>/dev/null || true

podman build --no-cache --pull=always \
    --manifest "${IMAGE}" \
    --platform "${PLATFORMS}" \
    -f Containerfile .

if [[ "${PUSH}" == "true" ]]; then
    podman manifest push --all "${IMAGE}" "docker://${IMAGE}"
    podman manifest push --all "${IMAGE}" "docker://${REPOSITORY}:latest"
    echo "Pushed ${IMAGE} and ${REPOSITORY}:latest"
fi
