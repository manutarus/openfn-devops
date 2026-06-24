#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " OpenFn Lightning Bundle Generator"
echo "=================================================="

if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed on this machine."
    echo "The bundle generator requires Docker to pull and export the OpenFn images."
    echo "Please install Docker and try again."
    exit 1
fi

# Versions
LIGHTNING_VERSION="v2.16.7"
WORKER_VERSION="v1.27.0"
POSTGRES_VERSION="15.12-alpine"

BUNDLE_DIR="openfn-release"
ARCHIVE_NAME="openfn-release.tar.gz"

echo "--> Cleaning up any previous builds..."
rm -rf ${BUNDLE_DIR} ${ARCHIVE_NAME} checksum.sha256
mkdir -p ${BUNDLE_DIR}

echo "--> Pulling required Docker images..."
docker pull openfn/lightning:${LIGHTNING_VERSION}
docker pull openfn/ws-worker:${WORKER_VERSION}
docker pull postgres:${POSTGRES_VERSION}

echo "--> Saving images to tarball (this may take a few minutes)..."
docker save -o ${BUNDLE_DIR}/images.tar \
  openfn/lightning:${LIGHTNING_VERSION} \
  openfn/ws-worker:${WORKER_VERSION} \
  postgres:${POSTGRES_VERSION}

echo "--> Copying configuration files..."
# docker-compose.yml will be created dynamically or copied from our source
cp bundle/docker-compose.yml ${BUNDLE_DIR}/
cp bundle/.env.example ${BUNDLE_DIR}/.env

echo "--> Injecting version tags into .env file..."
echo "LIGHTNING_VERSION=${LIGHTNING_VERSION}" >> ${BUNDLE_DIR}/.env
echo "WORKER_VERSION=${WORKER_VERSION}" >> ${BUNDLE_DIR}/.env
echo "POSTGRES_VERSION=${POSTGRES_VERSION}" >> ${BUNDLE_DIR}/.env

echo "--> Creating installation script for the air-gapped server..."
cp bundle/install.sh.template ${BUNDLE_DIR}/install.sh
chmod +x ${BUNDLE_DIR}/install.sh

echo "--> Creating the final transferable archive..."
tar -czvf ${ARCHIVE_NAME} ${BUNDLE_DIR}

echo "--> Generating checksum..."
sha256sum ${ARCHIVE_NAME} > checksum.sha256

echo "=================================================="
echo " Success! "
echo " Transfer '${ARCHIVE_NAME}' and 'checksum.sha256' to the air-gapped server via USB or SCP."
echo "=================================================="
