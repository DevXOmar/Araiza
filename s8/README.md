# Set 8 · Blood Bank Management System

Assigned source [`sarasrija/BloodBanksystem`](https://github.com/sarasrija/BloodBanksystem), default branch `main`. [Source lock](app/source.properties) pins [`c4ac661`](https://github.com/sarasrija/BloodBanksystem/tree/c4ac661abfa4b147d1e62c1f13b0b5df941eaa8c). Bootstrap clones the pinned source to ignored `app/upstream`. The upstream has no license file, so its sources are fetched on demand. It contains JSP pages and a WAR POM with Servlet 4.0.1 and JUnit 4.13.1. There are no upstream test classes or JDBC integration. A clean build produces `target/bloodbank.war`. Tomcat 9 provides `javax.servlet` compatibility and serves this file as `ROOT.war` at `/`.

The upstream has no Dockerfile. This set builds the actual Maven WAR in a multi-stage Dockerfile.

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
Set-Location Araiza/s8
Set-ExecutionPolicy -Scope Process Bypass
```

Wait for `docker info` to report `linux`. Run all local commands in `Araiza/s8`. For a PR preview switch the Araiza checkout to its review branch before entering the directory.

**macOS Terminal**
```bash
open -a Docker
brew services start jenkins-lts
command -v java mvn git docker
/usr/libexec/java_home -V
git clone https://github.com/DevXOmar/Araiza.git
cd Araiza/s8
```

Use `curl` for `curl.exe`. The setup equivalents are `bash scripts/setup.sh`, `bash scripts/setup.sh --env-only` and `bash scripts/setup.sh --fetch-only`. Use [PowerShell for macOS](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-macos) for verification scripts. The Docker and kubectl commands are shared.

## Ports and expected URLs

| Service | Address |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose | `http://127.0.0.1:8188/` and `/lab/` for the database companion |
| Nagios | `http://127.0.0.1:8898/nagios/` |
| Minikube | NodePort `30108` or forwarded `http://127.0.0.1:8318/` |
| EC2 | `http://PUBLIC_IPV4/` |
| EC2 Tomcat | `http://PUBLIC_IPV4:8080/` |

## Question 1 — Jenkins Scripted Pipeline

**Jenkins GUI** Open `http://localhost:8080/`. Under **Manage Jenkins → Plugins → Available plugins**, install Git, GitHub, Pipeline, JUnit and Pipeline Stage View. Under **Manage Jenkins → Tools**, configure Git and name the JDK `JDK21` and Maven `Maven3`. For installed tools, uncheck automatic installation and select the home directory above `bin`. If Git needs an explicit executable, use the path found by `Get-Command git`. Restart Jenkins after system PATH changes.

Maven runs the test lifecycle. The assigned repository has no test classes. The console may show **No tests to run**. Capture that output alongside the WAR.

1. **New Item → s8-pipeline → Pipeline → OK**. Set **Pipeline → Definition → Pipeline script**. Paste [Jenkinsfile](Jenkinsfile), leave **Use Groovy Sandbox** checked, and save.
2. The baseline Git source is `https://github.com/sarasrija/BloodBanksystem.git`. The public HTTPS checkout needs no credential. For automatic webhook builds, edit the `SOURCE_URL` and `SOURCE_BRANCH` default values in the pasted script to point to your writable training fork and exact branch, and run once manually to register Git SCM.

   `SOURCE_DIR` defaults to `bloodbankapp`. Change that one parameter for a different single-level folder. All Maven stages run inside it and the log prints the current `env.BUILD_NUMBER`. The explicit clean, install, test and package stages show each goal. Install already includes test and packaging.

3. **Configure → Build Triggers**. Enable **Poll SCM** at `H/5 * * * *` for recurring checks, or **GitHub hook trigger for GITScm polling** for push-only builds. Save and click **Build Now** to register Git SCM.
4. Inspect stages, **Build History → Console Output**, and download `bloodbank.war` from **Artifacts**.

For a reversible red build, set `SOURCE_BRANCH` to a nonexistent branch for one run then restore it. Maven exits the current `bat` or `sh` step on a failure. Later stages remain skipped.

If using a push trigger, a writable fork is required. In its **Settings → Webhooks → Add webhook**, enter the controller's reachable HTTPS URL plus `/github-webhook/`, select **application/json** and **Just the push event**. Check **Recent Deliveries** and the Jenkins SCM poll log. An upstream repo owner would have to install a webhook on the upstream. Compare a push to the configured branch with a push to a different branch.

**Troubleshooting** Read the first error in Console Output. On Windows confirm that the Pipeline uses `bat` and check the exact Jenkins tool names. If Jenkins needs Docker, inspect **services.msc → Jenkins → Properties → Log On**. Test `docker version` from the actual agent. Use a trusted interactive agent with Docker Desktop access, or configure the service account's Docker access and restart it. A successful interactive PowerShell test only verifies the logged-in user's access.

## Question 2 — AWS Academy EC2

**AWS console** [AWS Academy](https://awsacademy.instructure.com/) → **Login → Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved instance type, and at least 12–16 GiB of gp3 if allowed. Create or select a personal `.pem` key pair. Enable public IPv4 in a subnet with an internet gateway route.

Allow inbound TCP 22 from **My IP** (/32) and TCP **80** from the examiner's IP or permitted audience. Also allow TCP 8080 from the examiner for the Java variant. Keep DB ports closed. Use only synthetic data. If a small VM runs out of build memory, use a lab-approved larger instance.

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
cd Araiza/s8
bash aws/deploy-static.sh
curl -fsS http://127.0.0.1/
```

[deploy-static.sh](aws/deploy-static.sh) installs [the static page](aws/index.html) in `/var/www/html/index.html` and enables Apache. Nginx can also serve static files using its configured document root. Use one listener on port 80. Tomcat serves the Java app separately on 8080.

**Ubuntu EC2 terminal**
```bash
sudo systemctl status apache2 --no-pager
sudo apache2ctl configtest
sudo journalctl -u apache2 -n 50 --no-pager
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

To upload your laptop's copy of the page, run this in **PowerShell** after setting `$key` and `$ec2` above.

```powershell
scp -i "$key" ./aws/index.html "ubuntu@${ec2}:/tmp/araiza-s8-index.html"
```

Then in the **Ubuntu EC2 terminal**, run `bash aws/deploy-static.sh /tmp/araiza-s8-index.html`. To provision on first boot, paste [user-data.sh](aws/user-data.sh) into **Launch Instance → Advanced details → User data**. Set the clone branch there when reviewing the PR. Verify `sudo cloud-init status --long` and `sudo tail -60 /var/log/cloud-init-output.log`. User Data runs on first boot by default. Enabled Apache and Tomcat services start on subsequent boots.

[deploy.sh](aws/deploy.sh) installs Java 21 and Maven, verifies the Apache Tomcat 9 archive checksum, builds `bloodbank.war` and places it at `/opt/araiza-s8-tomcat/webapps/ROOT.war`. The enabled systemd unit starts Tomcat at boot.

**Ubuntu EC2 terminal**
```bash
sudo systemctl is-enabled araiza-s8-tomcat
sudo systemctl status araiza-s8-tomcat --no-pager
sudo journalctl -u araiza-s8-tomcat -n 80 --no-pager
ls -l /opt/araiza-s8-tomcat/webapps
sudo ss -lnt
```

**Laptop browser** Open `http://PUBLIC_IPV4/`. Open `http://PUBLIC_IPV4:8080/` for the separate WAR. If local curl works and external access times out, check public IPv4, the app port in the attached security group, subnet route and `sudo ufw status` in Ubuntu. If local curl fails, check listeners and server logs. For 404, check the context and whether `ROOT.war` deployed.

## Question 3 — Minikube and Nagios

Apply the provided [Deployment](k8s/deployment.yaml), [Service](k8s/service.yaml) and [namespace](k8s/namespace.yaml). This uses the actual Java image with startup, readiness and liveness probes.

**PowerShell**
```powershell
./scripts/setup.ps1
minikube start --driver=docker
minikube status
minikube image load araiza-s8:v1
kubectl --context minikube apply -f k8s/namespace.yaml
kubectl --context minikube -n araiza-s8 apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl --context minikube -n araiza-s8 rollout status deployment/araiza-s8 --timeout=240s
kubectl --context minikube -n araiza-s8 get 'deployment,pods,svc' -o wide
kubectl --context minikube -n araiza-s8 get endpointslices -l kubernetes.io/service-name=araiza-s8
minikube service araiza-s8 -n araiza-s8 --url
```

Expect 2 Ready Pods and endpoints. Keep the Minikube service tunnel open if the Docker driver starts one. Use its listed URL, or use port-forward in another terminal.

```powershell
kubectl --context minikube -n araiza-s8 port-forward service/araiza-s8 8318:8080
```

```powershell
curl.exe -fsS http://127.0.0.1:8318/
curl.exe -fsS http://127.0.0.1:8318/inventory.jsp
```

**PowerShell** Scale manually to 4, inspect Pod names, delete one and verify that the replacement has a different name. Use a second PowerShell window. If the deleted Pod was selected by port-forward, rerun the forward command.

```powershell
kubectl --context minikube -n araiza-s8 scale deployment/araiza-s8 --replicas=4
kubectl --context minikube -n araiza-s8 rollout status deployment/araiza-s8 --timeout=240s
kubectl --context minikube -n araiza-s8 get pods -o wide
$pod = kubectl --context minikube -n araiza-s8 get pods -l app=araiza-s8 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s8 delete pod $pod
kubectl --context minikube -n araiza-s8 rollout status deployment/araiza-s8 --timeout=240s
kubectl --context minikube -n araiza-s8 get pods -o wide
```

**PowerShell** Roll to the second image, then roll back. The build adds a visible revision label to the same upstream application. Reopen the forward after each rollout and check `http://127.0.0.1:8318/revision/index.txt` for `v2` and then `v1`.

```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s8:v2 .
minikube image load araiza-s8:v2
kubectl --context minikube -n araiza-s8 set image deployment/araiza-s8 web=araiza-s8:v2
kubectl --context minikube -n araiza-s8 rollout status deployment/araiza-s8 --timeout=240s
kubectl --context minikube -n araiza-s8 rollout history deployment/araiza-s8
```

```powershell
kubectl --context minikube -n araiza-s8 rollout undo deployment/araiza-s8
kubectl --context minikube -n araiza-s8 rollout status deployment/araiza-s8 --timeout=240s
```

**Troubleshooting** Replace a failing image with the correct loaded tag. Check startup logs and last termination reason for a crashing Pod. In a Pending Pod's events look for scheduling errors and resource shortages.

```powershell
$pod = kubectl --context minikube -n araiza-s8 get pods -l app=araiza-s8 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s8 describe pod $pod
kubectl --context minikube -n araiza-s8 logs $pod -c web --tail=60
kubectl --context minikube -n araiza-s8 logs $pod -c web --previous
kubectl --context minikube -n araiza-s8 get events --sort-by=.lastTimestamp
```

### Nagios monitoring

The [Compose overlay](nagios/compose.yaml) applies [host and service definitions](nagios/lab.cfg) for the portal, database TCP port and Docker Linux metrics. The SQL health check also detects database query failures through the companion.  The unprivileged [metrics agent](nagios/metrics.py) reads Linux CPU, memory, disk and uptime. On Docker Desktop these are metrics from the Docker Linux VM and its filesystem. No Docker socket or privileged container is needed.

**PowerShell** Build the Java image and start the monitoring services. For WordPress, complete first-run browser setup before testing the portal.

```powershell
./scripts/setup.ps1
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring pull nagios metrics
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios sv status nagios
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios python3 /opt/lab/check_lab.py http web 8080 / 1 3
```

**Browser** Open `http://127.0.0.1:8898/nagios/`. Use `nagiosadmin` and the password in your local `.env`. Check **Hosts**, **Services** and **Alert History**. CPU and memory use 75% WARNING and 90% CRITICAL. Disk uses 80%/95% used. Uptime warns below 120s and is critical below 30s. HTTP warns at 1s, becomes critical at 3s or on an error status. The dashboard and alert history record state changes. Outbound email is disabled.

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

## Question 4 — Web application and PostgreSQL 15

[compose.yaml](compose.yaml) runs the assigned WAR at `/` and the separately labeled companion WAR at `/lab/` in the same Tomcat service. The Blood Bank companion frontend stores synthetic inventory references and blood groups. The companion uses a restricted SQL account and prepared statements, checks a real query, and returns 503 when the database is unreachable. The application and DB share `s8-data-net`, use `db` as the hostname and retain data in `s8-db-data`. The database has no host port.

**PowerShell**
```powershell
./scripts/setup.ps1
docker compose config --quiet
docker compose up -d --build --wait --wait-timeout 180
docker compose ps
curl.exe -fsS http://127.0.0.1:8188/lab/health
```

**Browser** Open `http://127.0.0.1:8188/` for the original Java home page and `http://127.0.0.1:8188/lab/` for the database-backed form. Use a new synthetic reference if `Lab-01` is already saved.

```powershell
curl.exe -fsS -d 'reference=Lab-01' --data-urlencode 'bloodGroup=O+' http://127.0.0.1:8188/lab/records
```

**PowerShell** Read the record, simulate loss of the DB, then recreate its container.

```powershell
curl.exe -fsS http://127.0.0.1:8188/lab/records
docker compose kill db
curl.exe -i --max-time 8 http://127.0.0.1:8188/lab/health
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
curl.exe -fsS http://127.0.0.1:8188/lab/records
```

Expect `database OK` at startup, the saved row, an HTTP 503 during the outage, and the same row after replacement. A duplicate reference returns 409.  Use `docker compose logs --tail=60 db web` and verify the role/password from the original initialization if health fails.

Stop/start the stack, deploy a web-only rebuild, and recreate the stack while keeping the database volume.

```powershell
docker compose stop
docker compose start
docker compose up -d --wait
docker compose up -d --no-deps --build web
docker compose down
docker compose up -d --build --wait --wait-timeout 180
curl.exe -fsS http://127.0.0.1:8188/lab/records
```

## Scenario answers

### Question 1

1. Set `SOURCE_DIR` to `bloodbankapp`. All Maven stages and artifact paths read that one setting.
2. No. A nonzero exit from install throws a Pipeline error and later stages are skipped.
3. `bat` or `sh` throws on a failing exit code by default. Continuing requires deliberately handling that error, which this script does not do.
4. Use `echo "Build #${env.BUILD_NUMBER}"`.
5. Jenkins retrieves changes, orchestrates repeatable builds and checks, and stores results and artifacts for review.

### Question 2

1. Check Apache's service status and document root or index permissions first. Then verify the port 80 listener and inbound rule.
2. First confirm public IPv4 and TCP 80 inbound. SSH in, transfer the HTML, install/enable Apache, and test localhost before the public URL.
3. Allow TCP 8080 from the test client's IP on the attached security group. Confirm route and firewall if access still fails.
4. Use EC2 User Data for initial provisioning, then an enabled systemd unit for work required at every boot.
5. Keep SSH inbound limited to administrative IPs to reduce exposure to unauthorized access.

### Question 3

1. Use `kubectl --context minikube -n araiza-s8 get deployment,pods`, `describe pod POD` and events to identify scheduling, pull or startup failures.
2. Run `kubectl --context minikube -n araiza-s8 rollout undo deployment/araiza-s8` and watch rollout status before testing.
3. Use the assigned Pod name with `logs POD -c web` and `logs POD -c web --previous` in the set namespace. If needed, use `exec POD -c web -- curl -fsS http://127.0.0.1:8080/`.
4. For this container use the `sv status nagios` command in the monitoring steps. On a native installation use the configured systemd service name.
5. Nagios centralizes active checks, resource thresholds, state transitions and incident history in one dashboard.

### Question 4

1. Run `docker compose down` and retain named volumes. `stop` keeps the containers as well.
2. Run `docker compose up -d --build` for changed images, or `docker compose restart` for already-created containers.
3. Share the Compose files and `.env.example` separately. Use `docker image save -o "$env:TEMP/s8-images.tar" araiza-s8-compose:local araiza-s8-postgres:15` and `docker image load -i "$env:TEMP/s8-images.tar"`, or publish images to a registry. Use images matching the receiver’s platform, then run `docker compose up -d --no-build`.
4. The second host bind fails. Edit `WEB_PORT` or stop the lab service already using the port.
5. The custom data network limits membership and gives the web service a stable `db` DNS address as containers change.

## Common failures and fixes

- **Port in use.** In PowerShell, run `Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 8080,8188,8898,8318 }`. Identify the PID with `Get-Process -Id PID` after replacing PID. For Docker use `docker ps --format "table {{.Names}}	{{.Ports}}"`. On macOS use `lsof -nP -iTCP -sTCP:LISTEN`. Change the matching local port in `.env` where permitted.
- **Missing WAR.** Run `./scripts/setup.ps1 -FetchOnly` and `mvn -B -ntp -f app/upstream/pom.xml clean test package`. Expect `app/upstream/target/bloodbank.war`. For failed dependency resolution use `mvn -U -e -f app/upstream/pom.xml clean package` and inspect the failing repository or proxy.
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
| Containers Q4 | Working page and health, saved record before and after DB replacement. |
| Jenkins Q1 | Console phases, branch or trigger and archived `bloodbank.war`. |
| Minikube Q3 | 2 and 4 Ready replicas, endpoints, a new Pod name and HTTP at v2 and restored v1. |
| Nagios Q3 | Verified configuration, active HTTP and DB services, CPU/memory/disk/uptime, CRITICAL and recovery. |
| EC2 Q2 | Public IPv4, matching inbound TCP 80, local curl and external browser. |
