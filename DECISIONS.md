# OpenFn Deployment Trade-offs & Decisions

## 1. Image Handling

**Approach:** 
I used `docker save` to export the required container images (Lightning, ws-worker, Postgres) into a single tarball (`images.tar`), which is then loaded on the air-gapped server using `docker load`.

**Trade-offs & Reasoning:**
*   **Why `docker save/load`?** It is a simple approach with few moving parts and requires no additional infrastructure on the server beyond the already-installed Docker Engine.
*   **Alternative: Local Registry (e.g., Harbor or `distribution/registry`).** While a local registry would work especially well for multiple deployments introduces complexity and a higher risk of installation failure as it requries as it needs a bootstrap on the registry itself via `docker save/load` and then configure Docker to trust an insecure local registry

## 2. Secrets

**Approach:**
*   **Generation:** The `install.sh` script automatically generates secure, random base64 strings using `/dev/urandom` for `PRIMARY_ENCRYPTION_KEY`, `SECRET_KEY_BASE`, `WORKER_SECRET`, and `POSTGRES_PASSWORD` if they are not already set.
*   **Storage:** They are stored locally in the `.env` file on the air-gapped server's disk, and injected into the containers via Docker Compose.
*   **Rotation:** To rotate, the IT focal point would edit the `.env` file, replace the secret, and run `docker compose up -d` to recreate the containers. 

**What if there were 20 deployments?**
If deploying to 20 ministries, managing 20 unique `.env` files manually becomes a security and operational risk. 
*   I would use an infrastructure as code or configuration management tool like **Ansible**.
*   Ansible would be run from a central administrative jump host (or a portable laptop taken to the sites). 
*   Secrets would be securely generated centrally, stored encrypted using **Ansible Vault** (or integrated with a tool like HashiCorp Vault), and securely templated into the `.env` files on the target servers during the deployment playbook run.

## 3. Updates

**Scenario:** Upgrading from v2.16 to v2.20 in six months.

**What the IT Admin Does:**
1.  On their internet-connected jump host, pulls the latest OpenFn configuration repo and runs `build-bundle.sh` to generate a new offline installer.
2.  Transfers the new `openfn-release.tar.gz` bundle to the air-gapped server via USB/scp and extracts it.
3.  Runs the new `./install.sh`. (The script `docker load`s the new images. The `.env` file generation is skipped because the secrets already exist from the previous install).
4.  Docker Compose detects the image tag changes (e.g., `image: openfn/lightning:v2.20.0`) and recreates the containers using the existing volumes.

**Patch Update (v2.16.3 → v2.16.4)**
*   **Changes:** Almost entirely invisible to the user. `docker-compose.yml` image tags are updated.
*   **Risks:** Very low. Patch updates generally contain bug fixes and backward-compatible changes. The database schema usually remains unchanged.

**Minor Update (v2.16 → v2.17 or v2.20)**
*   **Changes:** Often includes database migrations, new environment variables, or changes to the deployment architecture (e.g., adding a new Redis dependency). 
*   **Risks:** 
    *   **Database Migrations:** The Lightning container will automatically run Ecto migrations on startup. If a migration fails, the container could crash-loop, leaving the application down. We must ensure a database backup is taken *before* `docker compose up -d` is run.
    *   **New Dependencies:** If v2.20 requires a new environment variable (e.g., a new secret), the old `.env` file won't have it. The `install.sh` script must be updated to intelligently append new required variables without overwriting old ones.

## 4. Observability

**Minimum Useful Monitoring:**
Since no telemetry can be shipped off-site, we must rely on local, on-box alerting that the ministry IT can easily monitor.
1.  **Container Health Checks:** We utilize Docker's native `healthcheck` in `docker-compose.yml` (e.g., curling `/health_check`). This allows Docker to automatically restart the container if the application freezes, providing self-healing.
2.  **Uptime robots (a lightweight local ping):** We would deploy a tiny, local instance of Uptime robot alongside OpenFn via the `docker-compose.yml`. 

**How we find out something is broken before they call:**
In a strict air-gapped environment with no outbound metrics, **we mathematically cannot know it's broken before they call.** 

*However*, we can make it so they call us *immediately* rather than 3 days later when a user complains. 
*   We can configure OpenFn (via its SMTP settings if an internal Ministry mail relay exists) or the local Uptime Kuma to send an **Email or SMS** alert to the ministry's internal IT helpdesk immediately when a health check fails. 
*   The IT focal point receives the local automated alert, and *they* pick up the phone to call us.

*What I skipped for time:* In a real scenario, I would have bundled `loki` and `promtail` into the `docker-compose.yml` to provide a local, web-based log viewer for the IT focal point, rather than asking them to use `docker compose logs` via SSH.
