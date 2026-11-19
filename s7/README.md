# Set 7 · Sports Management System

Assigned source [`sarasrija/SportSystem`](https://github.com/sarasrija/SportSystem), default branch `main`. [Source lock](app/source.properties) pins [`9ba843f`](https://github.com/sarasrija/SportSystem/tree/9ba843f1deafbb77222f6b75c39a89d263ed4f6a). Bootstrap clones the pinned source to ignored `app/upstream`. The upstream has no license file, so its sources are fetched on demand. It contains JSP pages and a WAR POM with Servlet 4.0.1 and JUnit 4.13.1. There are no upstream test classes or JDBC integration. A clean build produces `target/sportssystem.war`. Tomcat 9 provides `javax.servlet` compatibility and serves this file as `ROOT.war` at `/`.

The upstream has no Dockerfile. This set builds the actual Maven WAR in a multi-stage Dockerfile. The upstream registration form points to a servlet absent from its source. Verify the Java home and schedule pages separately from the Flask exercise.

## Prerequisites and startup

Install [Git](https://git-scm.com/downloads), [JDK 21](https://adoptium.net/temurin/releases/?version=21), [Maven 3.9](https://maven.apache.org/download.cgi), [Jenkins LTS](https://www.jenkins.io/download/), [Docker Desktop](https://www.docker.com/products/docker-desktop/), [Minikube](https://minikube.sigs.k8s.io/docs/start/), [kubectl](https://kubernetes.io/docs/tasks/tools/) and [Windows OpenSSH Client](https://learn.microsoft.com/windows-server/administration/openssh/openssh_install_firstuse). Docker Desktop includes Compose v2 and Buildx. Use the Linux engine and WSL 2 on Windows.

**Administrator PowerShell**
```powershell
Get-Service *jenkins*
Start-Service Jenkins
Get-Service Jenkins
```
If the service name differs, use the **Name** returned by discovery. Complete first-run setup and keep Jenkins authentication enabled.

**PowerShell**
```powershell
Start-Process "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
where.exe java
where.exe mvn
where.exe git
where.exe docker
Get-Command java,mvn,git,docker,kubectl,minikube,ssh | Select-Object Name,Source
java -version
mvn -version
docker info --format '{{.OSType}}'
docker compose version
git clone https://github.com/DevXOmar/Araiza.git
Set-Location Araiza/s7
Set-ExecutionPolicy -Scope Process Bypass
```

Wait for `docker info` to report `linux`. Run all local commands in `Araiza/s7`. For a PR preview switch the Araiza checkout to its review branch before entering the directory.

**macOS Terminal**
```bash
open -a Docker
brew services start jenkins-lts
command -v java mvn git docker
/usr/libexec/java_home -V
git clone https://github.com/DevXOmar/Araiza.git
cd Araiza/s7
```

Use `curl` for `curl.exe`. The setup equivalents are `bash scripts/setup.sh`, `bash scripts/setup.sh --env-only` and `bash scripts/setup.sh --fetch-only`. Use [PowerShell for macOS](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-macos) for verification scripts. The Docker and kubectl commands are shared.

## Ports and expected URLs

| Service | Address |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose | `http://127.0.0.1:8187/`  |
| Nagios | `http://127.0.0.1:8897/nagios/` |
| Minikube | NodePort `30107` or forwarded `http://127.0.0.1:8317/` |
| EC2 | `http://PUBLIC_IPV4:8080/` |

## Question 1 — Jenkins Scripted Pipeline

**Jenkins GUI** Open `http://localhost:8080/`. Under **Manage Jenkins → Plugins → Available plugins**, install Git, GitHub, Pipeline, JUnit and Pipeline Stage View. Under **Manage Jenkins → Tools**, configure Git and name the JDK `JDK21` and Maven `Maven3`. For installed tools, uncheck automatic installation and select the home directory above `bin`. If Git needs an explicit executable, use the path found by `Get-Command git`. Restart Jenkins after system PATH changes.

Maven runs the test lifecycle. The assigned repository has no test classes. The console may show **No tests to run**. Capture that output alongside the WAR.

1. **New Item → s7-pipeline → Pipeline → OK**. Set **Pipeline → Definition → Pipeline script**. Paste [Jenkinsfile](Jenkinsfile), leave **Use Groovy Sandbox** checked, and save.
2. The baseline Git source is `https://github.com/sarasrija/SportSystem.git`. The public HTTPS checkout needs no credential. For automatic webhook builds, edit the `SOURCE_URL` and `SOURCE_BRANCH` default values in the pasted script to point to your writable training fork and exact branch, and run once manually to register Git SCM.

3. **Configure → Build Triggers**. Enable **Poll SCM** at `H/5 * * * *` for recurring checks, or **GitHub hook trigger for GITScm polling** for push-only builds. Save and click **Build Now** to register Git SCM.
4. Inspect stages, **Build History → Console Output**, and download `sportssystem.war` from **Artifacts**.

The Scripted Pipeline uses `node { }` for agent allocation and `tool` for Maven and JDK. `deleteDir()` clears the workspace before checkout. Maven then runs clean, compile and package. The trigger checkboxes are set in the Jenkins GUI.

If using a push trigger, a writable fork is required. In its **Settings → Webhooks → Add webhook**, enter the controller's reachable HTTPS URL plus `/github-webhook/`, select **application/json** and **Just the push event**. Check **Recent Deliveries** and the Jenkins SCM poll log. An upstream repo owner would have to install a webhook on the upstream. Compare a push to the configured branch with a push to a different branch.

**Troubleshooting** Read the first error in Console Output. On Windows confirm that the Pipeline uses `bat` and check the exact Jenkins tool names. If Jenkins needs Docker, inspect **services.msc → Jenkins → Properties → Log On**. Test `docker version` from the actual agent. Use a trusted interactive agent with Docker Desktop access, or configure the service account's Docker access and restart it. A successful interactive PowerShell test only verifies the logged-in user's access.

## Question 2 — AWS Academy EC2

**AWS console** [AWS Academy](https://awsacademy.instructure.com/) → **Login → Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved instance type, and at least 12–16 GiB of gp3 if allowed. Create or select a personal `.pem` key pair. Enable public IPv4 in a subnet with an internet gateway route.

Allow inbound TCP 22 from **My IP** (/32) and TCP **8080** from the examiner's IP or permitted audience.  Keep DB ports closed. Use only synthetic data. If a small VM runs out of build memory, use a lab-approved larger instance.

**PowerShell** Supply the actual downloaded key path and instance IP.

```powershell
$key = (Resolve-Path "$env:USERPROFILE\Downloads\YOUR_KEY.pem").Path
$ec2 = Read-Host 'EC2 public IPv4'
ssh -i "$key" "ubuntu@$ec2"
```

If OpenSSH rejects the key ACL, in the key's **Properties → Security → Advanced** disable inheritance and retain read access for your Windows user. On macOS use `chmod 400 ~/Downloads/YOUR_KEY.pem` and `ssh -i ~/Downloads/YOUR_KEY.pem ubuntu@PUBLIC_IPV4`.

**Ubuntu EC2 terminal** The script fetches the assigned source using its pinned commit. To run from the PR, add `--branch lab/nine-set-execution` to the Araiza clone command.

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/DevXOmar/Araiza.git
cd Araiza/s7
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

[deploy.sh](aws/deploy.sh) installs Java 21 and Maven, verifies the Apache Tomcat 9 archive checksum, builds `sportssystem.war` and places it at `/opt/araiza-s7-tomcat/webapps/ROOT.war`. The enabled systemd unit starts Tomcat at boot. The script also installs and enables Docker for the sports exercise.

**Ubuntu EC2 terminal**
```bash
sudo systemctl is-enabled araiza-s7-tomcat
sudo systemctl status araiza-s7-tomcat --no-pager
sudo journalctl -u araiza-s7-tomcat -n 80 --no-pager
ls -l /opt/araiza-s7-tomcat/webapps
sudo ss -lnt
```

**Laptop browser** Open `http://PUBLIC_IPV4:8080/`.  If local curl works and external access times out, check public IPv4, the app port in the attached security group, subnet route and `sudo ufw status` in Ubuntu. If local curl fails, check listeners and server logs. For 404, check the context and whether `ROOT.war` deployed.

## Question 3 — Minikube and Nagios

Apply the provided [Deployment](k8s/deployment.yaml), [Service](k8s/service.yaml) and [namespace](k8s/namespace.yaml). This uses the actual Java image with startup, readiness and liveness probes.

**PowerShell**
```powershell
./scripts/setup.ps1
minikube start --driver=docker
minikube status
minikube image load araiza-s7:v1
kubectl --context minikube apply -f k8s/namespace.yaml
kubectl --context minikube -n araiza-s7 apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl --context minikube -n araiza-s7 rollout status deployment/araiza-s7 --timeout=240s
kubectl --context minikube -n araiza-s7 get 'deployment,pods,svc' -o wide
kubectl --context minikube -n araiza-s7 get endpointslices -l kubernetes.io/service-name=araiza-s7
minikube service araiza-s7 -n araiza-s7 --url
```

Expect 2 Ready Pods and endpoints. Keep the Minikube service tunnel open if the Docker driver starts one. Use its listed URL, or use port-forward in another terminal.

```powershell
kubectl --context minikube -n araiza-s7 port-forward service/araiza-s7 8317:8080
```

```powershell
curl.exe -fsS http://127.0.0.1:8317/
curl.exe -fsS http://127.0.0.1:8317/schedule.jsp
```

**PowerShell** Scale manually to 4, inspect Pod names, delete one and verify that the replacement has a different name. Use a second PowerShell window. If the deleted Pod was selected by port-forward, rerun the forward command.

```powershell
kubectl --context minikube -n araiza-s7 scale deployment/araiza-s7 --replicas=4
kubectl --context minikube -n araiza-s7 rollout status deployment/araiza-s7 --timeout=240s
kubectl --context minikube -n araiza-s7 get pods -o wide
$pod = kubectl --context minikube -n araiza-s7 get pods -l app=araiza-s7 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s7 delete pod $pod
kubectl --context minikube -n araiza-s7 rollout status deployment/araiza-s7 --timeout=240s
kubectl --context minikube -n araiza-s7 get pods -o wide
```

**PowerShell** Roll to the second image, then roll back. The build adds a visible revision label to the same upstream application. Reopen the forward after each rollout and check `http://127.0.0.1:8317/revision/index.txt` for `v2` and then `v1`.

```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s7:v2 .
minikube image load araiza-s7:v2
kubectl --context minikube -n araiza-s7 set image deployment/araiza-s7 web=araiza-s7:v2
kubectl --context minikube -n araiza-s7 rollout status deployment/araiza-s7 --timeout=240s
kubectl --context minikube -n araiza-s7 rollout history deployment/araiza-s7
```

```powershell
kubectl --context minikube -n araiza-s7 rollout undo deployment/araiza-s7
kubectl --context minikube -n araiza-s7 rollout status deployment/araiza-s7 --timeout=240s
```

**Troubleshooting** Replace a failing image with the correct loaded tag. Check startup logs and last termination reason for a crashing Pod. In a Pending Pod's events look for scheduling errors and resource shortages.

```powershell
$pod = kubectl --context minikube -n araiza-s7 get pods -l app=araiza-s7 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s7 describe pod $pod
kubectl --context minikube -n araiza-s7 logs $pod -c web --tail=60
kubectl --context minikube -n araiza-s7 logs $pod -c web --previous
kubectl --context minikube -n araiza-s7 get events --sort-by=.lastTimestamp
```

### Nagios monitoring

The [Compose overlay](nagios/compose.yaml) applies [host and service definitions](nagios/lab.cfg) for the portal, database TCP port and Docker Linux metrics. The monitoring overlay runs a separate assigned-WAR Tomcat instance for its own HTTP check. Flask readiness checks both PostgreSQL and Redis. The unprivileged [metrics agent](nagios/metrics.py) reads Linux CPU, memory, disk and uptime. On Docker Desktop these are metrics from the Docker Linux VM and its filesystem. No Docker socket or privileged container is needed.

**PowerShell** Build the Java image and start the monitoring services. For WordPress, complete first-run browser setup before testing the portal.

```powershell
./scripts/setup.ps1
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring pull nagios metrics
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios sv status nagios
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios python3 /opt/lab/check_lab.py http proxy 80 / 1 3
```

**Browser** Open `http://127.0.0.1:8897/nagios/`. Use `nagiosadmin` and the password in your local `.env`. Check **Hosts**, **Services** and **Alert History**. CPU and memory use 75% WARNING and 90% CRITICAL. Disk uses 80%/95% used. Uptime warns below 120s and is critical below 30s. HTTP warns at 1s, becomes critical at 3s or on an error status. The dashboard and alert history record state changes. Outbound email is disabled.

**PowerShell** Test both threshold exits using actual sampled CPU data, without running a load generator. Expect return codes 1 and 2.

```powershell
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios python3 /opt/lab/check_lab.py metric metrics cpu 0 101
$LASTEXITCODE
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios python3 /opt/lab/check_lab.py metric metrics cpu 0 0
$LASTEXITCODE
```

**PowerShell and browser** Stop DB, wait for **Database TCP** to reach CRITICAL, restart and wait for OK. Repeat with web and **Portal HTTP**. Give Nagios 30–60 seconds to display the hard state before continuing.

```powershell
docker compose stop db
docker compose start db
docker compose stop web
docker compose start web
```

If the website loads but Nagios reports no process, check `docker compose -f compose.yaml -f nagios/compose.yaml logs nagios` and the daemon status above. After editing the host definitions, validate before scheduling the change.

```powershell
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios sv restart nagios
```

## Question 4 — Flask, PostgreSQL and Redis

[compose.yaml](compose.yaml) launches the [fixtures Flask service](flask/app.py), a private PostgreSQL database and Redis. [Dockerfile](flask/Dockerfile) installs the pinned [dependencies](flask/requirements.txt) and runs Gunicorn. [Database initialization](db/init-db.sh) creates the restricted role. Health checks gate startup. Flask performs `SELECT 1` and Redis `PING` for readiness, inserts fixtures in PostgreSQL and increments a Redis visit counter for reads. Nginx fronts web replicas on a single host port. Redis uses AOF on `s7-redis-data`, PostgreSQL uses `s7-db-data`.

**PowerShell**
```powershell
./scripts/setup.ps1 -EnvOnly
docker compose config --quiet
docker compose up -d --build --wait --wait-timeout 180
docker compose ps
curl.exe -fsS http://127.0.0.1:8187/health
curl.exe -fsS -d 'name=Saturday+Final' http://127.0.0.1:8187/fixtures
curl.exe -fsS http://127.0.0.1:8187/fixtures
curl.exe -fsS http://127.0.0.1:8187/fixtures
docker compose exec -T redis redis-cli GET fixture-reads
```

**Browser** Open `http://127.0.0.1:8187/`. Health returns PostgreSQL and Redis OK. The read response includes the saved fixture, the counter and the serving container hostname.

**PowerShell** Change the heading in [app.py](flask/app.py) for visible rebuild evidence. Compare IDs before and after rebuilding only web.

```powershell
docker compose ps -q db redis
docker compose up -d --no-deps --build web
docker compose ps -q db redis
docker compose up -d --no-deps --scale web=2 web
docker compose ps web proxy
1..8 | ForEach-Object { curl.exe -fsS http://127.0.0.1:8187/fixtures }
docker compose down
docker compose up -d --wait --wait-timeout 180
curl.exe -fsS http://127.0.0.1:8187/fixtures
docker compose exec -T redis redis-cli GET fixture-reads
```

Expect unchanged DB and Redis IDs from the web-only rebuild, and both instance names after the proxy refreshes DNS. After down/up the fixture and Redis counter survive. For startup failures use `docker compose logs --tail=60 web db redis proxy`. For a conflicting host port, edit `WEB_PORT` in `.env` and apply again.

## Scenario answers

### Question 1

1. The Clean workspace stage calls `deleteDir()` before Git checkout.
2. The `tool name: 'Maven3', type: 'maven'` step fails when no tool by that name is configured.
3. In **Configure → Build Triggers**, select **GitHub hook trigger for GITScm polling** and use the push webhook. Disable periodic polling for a push-only job.
4. `compile` compiles source in `target` and preserves prior output. `clean` deletes previous output.
5. Poll SCM checks Git on a schedule. A webhook tells Jenkins to check when GitHub receives an event.

### Question 2

1. The script installs `sportssystem.war` as `/opt/araiza-s7-tomcat/webapps/ROOT.war`. Tomcat deploys files from `webapps` and names the context after the WAR.
2. Check the request path, exact WAR name, permissions, and Tomcat deployment logs. With `ROOT.war` use `/` or `/schedule.jsp`.
3. Associate an Elastic IP if Academy permits it. A normal public IP can change after stop/start.
4. Provide controlled egress through a NAT gateway for a private subnet or an approved package mirror. In a public subnet use an internet gateway route and public IPv4.
5. On Ubuntu run `sudo systemctl enable --now araiza-s7-tomcat` and confirm `systemctl is-enabled araiza-s7-tomcat`.

### Question 3

1. Use `kubectl --context minikube -n araiza-s7 describe pod POD` and `logs POD -c web --previous` with the same context and namespace. Verify startup errors, limits and probes.
2. Check `describe pod` events for inadequate node resources, failed image placement, taints or unsatisfied scheduling rules.
3. Compare probe path and port, application logs and each Pod's events. Correct the manifest or app and watch the new rollout.
4. Run the monitoring daemon status and Nagios config checks above. Investigate the container logs and restart Nagios after repair.
5. Confirm the file is mounted in `conf.d`, validate with `nagios -v` as above, restart the daemon and refresh Hosts.

### Question 4

1. Use a backend service and a separate worker service so each can be deployed, stopped and scaled independently.
2. A second bind to the same host address and port fails. Publish distinct host ports or put both apps behind a reverse proxy.
3. Run `docker compose up -d --no-deps --build web` and compare the DB and Redis container IDs.
4. A container listener needs a host port mapping and the browser must use the mapped port. Check `docker ps`, logs and local curl.
5. Use `docker ps --filter publish=3000`, then `Get-NetTCPConnection -LocalPort 3000` to check a Windows host process.

## Common failures and fixes

- **Port in use.** In PowerShell, run `Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 8080,8187,8897,8317 }`. Identify the PID with `Get-Process -Id PID` after replacing PID. For Docker use `docker ps --format "table {{.Names}}	{{.Ports}}"`. On macOS use `lsof -nP -iTCP -sTCP:LISTEN`. Change the matching local port in `.env` where permitted.
- **Missing WAR.** Run `./scripts/setup.ps1 -FetchOnly` and `mvn -B -ntp -f app/upstream/pom.xml clean test package`. Expect `app/upstream/target/sportssystem.war`. For failed dependency resolution use `mvn -U -e -f app/upstream/pom.xml clean package` and inspect the failing repository or proxy.
- **Engine inactive.** Check `docker context ls` and `docker version`. Wait for the Linux engine. Check permission under the Jenkins agent user separately.
- **Database unhealthy.** Run `docker compose ps` and `docker compose logs --tail=80 web db`. Initialization uses credentials from the first boot of the named volume. Restore the original `.env` or rotate the database account explicitly.
- **No Nagios status.** Verify daemon status and config, then wait for the next active check. Include both Compose files when inspecting monitoring.

## Verify and clean up

**PowerShell** Run `./scripts/setup.ps1` first. Verification inserts one synthetic record through HTTP.

```powershell
./scripts/verify.ps1 -RecreateDatabase -Kubernetes
```

Omit `-RecreateDatabase` to avoid restarting the DB. Omit `-Kubernetes` to skip its checks. For Kubernetes only use `./k8s/verify.ps1`. The script validates endpoint selection, root and detail HTTP, scaling, Pod replacement, update and rollback through port-forward.

Once finished, stop port-forwards with Ctrl+C and remove this set's Compose containers and Kubernetes namespace.

```powershell
./scripts/cleanup.ps1 -Kubernetes
```

On macOS use `pwsh -File scripts/cleanup.ps1 -Kubernetes`. Cleanup leaves the database volumes, WordPress files, Redis data and `.env` wherever present. Stop any webhook tunnel and disable the practice webhook. In AWS, stop for later use or terminate the instance when evidence is saved. Release lab-only Elastic IPs and retained disks as allowed, then end the Academy lab.

## Evidence checklist

| Exercise | Capture |
| --- | --- |
| Containers Q4 | Working page and health, saved record before and after DB replacement plus Redis counter. |
| Jenkins Q1 | Console phases, branch or trigger and archived `sportssystem.war`. |
| Minikube Q3 | 2 and 4 Ready replicas, endpoints, a new Pod name and HTTP at v2 and restored v1. |
| Nagios Q3 | Verified configuration, active HTTP and DB services, CPU/memory/disk/uptime, CRITICAL and recovery. |
| EC2 Q2 | Public IPv4, matching inbound TCP 8080, local curl and external browser. |
