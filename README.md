# OpenFn Lightning Air-Gapped Deployment

## Overview

This repository contains the necessary scripts and documentation to successfully deploy OpenFn Lightning into an air-gapped environment.

## Key Assumptions

*(Explicitly stated to ensure alignment with the deployment environment constraints)*

1. **Host OS and Utilities:** The air-gapped production server is running Ubuntu 22.04 LTS (or a compatible Linux distribution). Standard utilities like `tar`, `gzip`, `sha256sum`, `curl`, and `openssl` are present (these are default on Ubuntu).
2. **Docker Engine:** The production server has been pre-provisioned by the Ministry's infrastructure team with a modern version of Docker Engine and **Docker Compose v2** (accessed via `docker compose`, not the older `docker-compose` binary).
3. **Admin Host:** The IT Administrator has access to an internet-connected jump host (Linux or macOS) with `bash` and Docker installed to generate the deployment bundle.
4. **Network Topology:** The production server has absolutely zero outbound internet access, but allows incoming connections over a local secure subnet (e.g., via a jump host) to transfer files via `scp` or physically via USB.

The approach is split into two phases:
1. **Preparation (Internet-connected Jump Host):** A bash script (`bundle/build-bundle.sh`) is run on an internet connected machine. To start, the IT administrator clones the source repository (`git clone git@github.com:manutarus/openfn-devops.git`) onto their jump host. They then run the build script, which pulls the necessary Docker images, exports them into a portable tarball, templates a secure installation script, and packages everything (along with configurations and a checksum) into a single, transferable archive.

2. **Installation** We assume the Ministry has already provisioned the production server with the OS, Docker, and firewall rules in place. The generated archive (`openfn-release.tar.gz`) is simply transferred (`scp` or USB) to this destination server. An IT focal point extracts it and runs the self contained `install.sh`. This script loads the images from disk, generates random secure passwords for the `.env` file, and brings up the application via Docker Compose without needing to pull anything from the internet.

## Contents
- `bundle/`: Contains the `build-bundle.sh` script, `install.sh.template`, production `docker-compose.yml`, and `.env.example` templates.
- `RUNBOOK.md`: The step-by-step installation guide for the Ministry IT focal point.
- `DECISIONS.md`: A memo explaining the trade-offs regarding image handling, secret generation, updates, and observability.


