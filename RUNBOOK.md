# OpenFn Lightning Installation Guide

This guide walks you through the end-to-end process of packaging and deploying OpenFn Lightning for a strictly air-gapped environment. Since the target server has no internet connection, the process is divided into two phases: preparing the bundle on an internet-connected admin host, and deploying it on the air-gapped production server.

## Prerequisites

- **Admin Host (Internet-connected)**: A Linux/macOS machine with Docker and bash installed, used to prepare the release bundle.
- **Production Server (Air-gapped)**: A Linux server (recommended: 8GB of RAM and 4 vCPUs). The infrastructure team must have already provisioned it with the OS and Docker Engine.
- **Network Access**: You must be able to transfer files from the Admin Host to the Production Server (e.g., via `scp` or a physical USB drive).

---

## Phase 1: Generating the Offline Bundle (On the Admin Host)

You will use the admin host to download the necessary Docker images and package them into a portable offline installer. This allows you to easily upgrade to future releases by simply re-running this process with updated version numbers.

1. On the admin host, clone the deployment repository and navigate into it:
   ```bash
   git clone https://github.com/manutarus/openfn-devops.git && cd openfn-devops
   ```

2. Run the build script:
   ```bash
   ./bundle/build-bundle.sh
   ```
   *Note: If you need to upgrade to a newer version of OpenFn Lightning in the future, simply edit the `LIGHTNING_VERSION` or `WORKER_VERSION` variables at the top of this script before running it. You can check for the latest version tags on [Docker Hub for Lightning](https://hub.docker.com/r/openfn/lightning/tags) and [Docker Hub for the Worker](https://hub.docker.com/r/openfn/ws-worker/tags).*

3. The script will pull the required Docker images, generate an installation script, and package everything into two files:
   - `openfn-release.tar.gz` (The complete offline bundle)
   - `checksum.sha256` (For verifying file integrity)

4. Transfer these two files to the air-gapped production server using `scp` (or a USB drive):
   ```bash
   scp openfn-release.tar.gz checksum.sha256 <username>@<production_server_ip>:~/
   ```

---

## Phase 2: Deploying to the Production Server (Air-gapped)

Switch your terminal to the air-gapped production server where you transferred the files. Assuming you used the `scp` command above, these files will now be sitting in your user's home directory (`~`).

### Step 1: Verify the Transfer
Ensure the archive was not corrupted during the transfer:
```bash
sha256sum -c checksum.sha256
```
*(You should see an output that says: `openfn-release.tar.gz: OK`)*

### Step 2: Unpack the Bundle
Extract the contents of the archive and navigate into the directory:
```bash
tar -xzvf openfn-release.tar.gz && cd openfn-release
```

### Step 3: Run the Installer
Execute the self-contained installer script:
```bash
sudo ./install.sh
```
**What the script does automatically:**
- Loads the Docker images from the local archive directly into the Docker daemon.
- Generates secure, randomized cryptographic passwords, worker secrets, and database credentials in the `.env` file.
- Runs the necessary database schema migrations.
- Starts the Database, Web Server, and Worker containers in the background.

### Step 4: Verify the Services
It takes a moment for the database to initialize and the web server to boot up.

1. Check if the containers are running correctly:
   ```bash
   sudo docker compose ps
   ```
   You should see `postgres`, `web`, and `worker` listed with the state `Up` and `(healthy)`.

2. **Definitive Verification:** Verify that Lightning is successfully responding to requests:
   ```bash
   curl -i http://localhost:80/health_check
   ```
   If the output returns an `HTTP/1.1 200 OK` followed by a `Hello you!` message, **the installation is successful!** You can now access the OpenFn UI via a web browser pointing to this server's IP address.

---

## Troubleshooting

**Failure Scenario:** The `postgres` container fails to start, which causes the `web` and `worker` containers to crash endlessly. 

**Diagnosis:**
1. Run `sudo docker compose ps`. If `postgres` says `Exit 1` or `restarting`, there is a problem.
2. Check the database logs:
   ```bash
   sudo docker compose logs postgres
   ```
3. If you see an error similar to `initdb: could not change permissions of directory "/var/lib/postgresql/data": Operation not permitted`, this means Docker is struggling with file permissions for the database volume (often caused by leftover root files from a previous run).

**Resolution:**
1. Stop all containers:
   ```bash
   sudo docker compose down
   ```
2. Remove the faulty database volume. **(Warning: This deletes the database data, which is safe ONLY during initial setup):**
   ```bash
   sudo docker volume rm openfn-release_postgres
   ```
3. Restart the installation script:
   ```bash
   sudo ./install.sh
   ```
