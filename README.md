## Environment layout (key directories)

```text
/opt
└─ Informatica
   └─ downloads
      ├─ informatica
      │  ├─ V41976-01_1of4.zip
      │  ├─ V41976-01_2of4.zip
      │  ├─ V41976-01_3of4.zip
      │  ├─ V41976-01_4of4.zip
      │  └─ Oracle_All_OS_Prod.key
      ├─ jdk
      │  └─ zulu8.74.0.17-ca-fx-jdk8.0.392-linux_x64.tar.gz
      └─ sqldeveloper
         └─ sqldeveloper-21.4.3-063.0100.noarch.rpm


/mnt/hgfs/rocky/informatica_automation_rl8 (this repo)
├─ scripts
├─ docs
├─ logs (gitignored)
├─ informatica_response_files (gitignored)
└─ docker-compose.yml
```

## This project delivers a fully automated, idempotent installation of Informatica PowerCenter 9.5.1 HF2 on Rocky Linux 8. It orchestrates Zulu JDK, Oracle XE (via Docker), SQL Developer, and a non-interactive server install driven by Expect. The runbooks harden hostname resolution, open required ports, and verify services so the Informatica Administrator console is reachable from the host machine. The design emphasizes reproducibility, clear logs, and safe re-runs for rapid rebuilds and troubleshooting.

# Informatica PowerCenter Automation - Final Report

## Overview
Goal: Fully automate installation of Informatica PowerCenter 9.5.1 HF2 and dependencies (JDK, Oracle XE, SQL Developer) on Rocky Linux 8 using unattended scripts. Heavy archives are pre-staged by the user; scripts extract, install, configure, and verify.

## Environment
- Host: Windows 11, shared folder mounted in Rocky VM as `/mnt/hgfs/rocky/informatica_automation_rl8`
- VM: Rocky Linux 8 (non-root user with sudo)
- Docker: Oracle XE container orchestrated via scripts and `docker-compose.yml`
- Java: Zulu JDK 8u392 (with JavaFX)

## Paths (current)
- Base repo: `/mnt/hgfs/rocky/informatica_automation_rl8`
- Downloads root: `/opt/Informatica/downloads`
  - Informatica zips: `/opt/Informatica/downloads/informatica/`
  - JDK archive: `/opt/Informatica/downloads/jdk/`
  - SQL Developer RPM: `/opt/Informatica/downloads/sqldeveloper/`
  - License key: `/opt/Informatica/downloads/informatica/Oracle_All_OS_Prod.key`
- Temp install workspace: `/opt/temp_install_files`
  - Main zips staging: `/opt/temp_install_files/informatica_extracted_main_zips`
  - Server payload: `/opt/temp_install_files/informatica_server_installer_payload` (contains `install.sh`)
- Informatica install target: `/opt/Informatica/9.5.1`
- Logs: `/mnt/hgfs/rocky/informatica_automation_rl8/logs`
- Response files: `/mnt/hgfs/rocky/informatica_automation_rl8/informatica_response_files`

## Project Structure (key files)
- `scripts/00_config.sh` configuration (paths, credentials, ports)
- `scripts/main_setup.sh` orchestrator (01 → 07; 08 optional)
- `scripts/01_download_prerequisites.sh` sanity checks for staged artifacts
- `scripts/02_install_jdk.sh` installs Zulu JDK 8 (JavaFX)
- `scripts/03_start_oracle_docker.sh`, `scripts/manage_oracle_docker.sh` start/config Oracle XE and users
- `scripts/04_install_sqldeveloper.sh`, `scripts/05_configure_sqldeveloper.sh`
- `scripts/06_prepare_informatica_installers.sh` prepares Informatica installer (robust, idempotent)
- `scripts/07_install_informatica_server.sh` unattended install via expect
- `scripts/08_configure_informatica_services.sh` (optional post-install services)
- `docker-compose.yml` Oracle XE container definition
 - Removed redundant helpers: `07.5_fix_informatica_installation.sh`, `jdk_cleanup.sh`, `remove.sh`, `inputs.txt`.
 - Sensitive or scratch files like `crendentials_overiew.txt` should not be committed.

## What’s working now
- JDK 8 (Zulu 8u392): installed to `/opt/java/...`, alternatives and profile configured.
- Oracle XE via Docker: container up, users `INFA_DOM`, `INFA_REP`, `HR` created; connection tests pass.
- SQL Developer: installed (pre-existing), configured connections and launcher; test connections pass.
- Informatica installer preparation (Step 06):
  - Extracts V41976-01_1of4.zip … 4of4.zip to `/opt/temp_install_files/informatica_extracted_main_zips` (idempotent; skips if present).
  - Extracts DAC split zip locally in `/var/tmp/infa_prepare` to avoid HGFS issues; copies results back.
  - Extracts `951HF2_Server_Installer_linux-x64.tar` to `/opt/temp_install_files/informatica_server_installer_payload` (contains `install.sh`).
  - Confirms license key at `/opt/Informatica/downloads/informatica/Oracle_All_OS_Prod.key`.
- Informatica Server installation (Step 07): successfully completes, permissions fixed; Admin URL printed.

## Recent fixes and changes
- Expect-driven install:
  - Single-quoted heredoc; reads config via environment vars; matches real prompts (continue, i9Pi=n, console mode, HTTPS disable, JDBC params=no).
  - Handles domain/node prompts; resolves early prompt variants; streams output to a log.
- Hostname and firewall:
  - Ensures `/etc/hosts` maps `INFA_NODE_HOST` to the VM’s primary IPv4 to avoid domain ping hangs.
  - Opens ports `6005-6010/tcp` and `6008/tcp` in firewalld (if active).
- SQL Developer installation:
  - Detects launcher via rpm/FS search (e.g., `/usr/local/bin/sqldeveloper`).
  - Correct version parsing for `~/.sqldeveloper/<ver>/product.conf`; safe writes without sudo numeric UID.
  - System conf update attempted via rpm/search when present.
- Cleanup script:
  - Preserves `DOWNLOAD_DIR` even when inside `INFA_INSTALL_BASE_DIR`.

## How to run
Run full orchestrator (non-root user):
```bash
bash /mnt/hgfs/rocky/informatica_automation_rl8/scripts/main_setup.sh
```
Run individual steps:
```bash
# Prepare installers (idempotent)
bash /mnt/hgfs/rocky/informatica_automation_rl8/scripts/06_prepare_informatica_installers.sh

# Install Informatica server
bash /mnt/hgfs/rocky/informatica_automation_rl8/scripts/07_install_informatica_server.sh
```

## Prerequisites to place manually
- `/opt/Informatica/downloads/informatica/`:
  - `V41976-01_1of4.zip` … `V41976-01_4of4.zip`
  - `Oracle_All_OS_Prod.key`
- `/opt/Informatica/downloads/jdk/`: `zulu8.74.0.17-ca-fx-jdk8.0.392-linux_x64.tar.gz`
- `/opt/Informatica/downloads/sqldeveloper/`: `sqldeveloper-21.4.3-063.0100.noarch.rpm`

## Verification
- JDK: `java -version` should show 1.8.0_392 (Zulu)
- Oracle XE: connect via SQL*Plus within container; tests are automated in Step 03
- SQL Developer: launch `/usr/local/bin/sqldeveloper`, connections pre-populated
- Informatica (post-07): verify presence of `infaservice.sh` and `infacmd.sh` under `/opt/Informatica/9.5.1`
- Services up (VM):
  ```bash
  /opt/Informatica/9.5.1/tomcat/bin/infaservice.sh startup
  ss -lntp | grep -E '(:6005|:6008)'
  curl -I http://infa-server:6008
  ```
- Access from host (Windows): add hosts entry or use VM IP:
  - Add `192.168.<vm-ip> infa-server` to `C:\\Windows\\System32\\drivers\\etc\\hosts`, then open `http://infa-server:6008`
  - Or directly browse `http://<vm-ip>:6008`

## Troubleshooting
- Logs: see latest file under `/mnt/hgfs/rocky/informatica_automation_rl8/logs/`
- Step 06: ensures idempotent extraction; verify server payload under `/opt/temp_install_files/informatica_server_installer_payload`
- Step 07:
  - If it hangs at “Pinging domain…”, ensure `/etc/hosts` maps `infa-server` to the VM IPv4 and that firewalld allows ports 6005–6010, 6008.
  - Check `Informatica_9.5.1_Services_HotFix2.log` and `services/*/logs` under `/opt/Informatica/9.5.1`.
  - Start services manually: `/opt/Informatica/9.5.1/tomcat/bin/infaservice.sh startup`

## Limitations & Notes
- Oracle and Informatica artifacts require appropriate licenses.
- Shared HGFS path is only used for repo/logs; heavy extraction runs on local disk to avoid I/O issues.
- Post-install service provisioning (`scripts/08_configure_informatica_services.sh`) is optional and can be run after successful Step 07.
