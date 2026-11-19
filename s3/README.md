# Set 3 · Online Recruitment System

Assigned source [`ssvkotamraju/ORS`](https://github.com/ssvkotamraju/ORS), default branch `main`. [Source lock](app/source.properties) pins [`bb359e8`](https://github.com/ssvkotamraju/ORS/tree/bb359e8da57fc1907a41668ed2d6c0a41f38ca53). Bootstrap clones the pinned source to ignored `app/upstream`. The upstream has no license file, so its sources are fetched on demand. It contains JSP pages and a WAR POM with JUnit 4.13.1 and container Servlet 4.0/JSP APIs. There are no upstream test classes or JDBC integration. A clean build produces `target/ORS.war`. Tomcat 9 provides `javax.servlet` compatibility and serves this file as `ROOT.war` at `/`.

The upstream Dockerfile uses Tomcat 9 and copies `target/*.war`. This set builds from clean source and copies `ORS.war` by name.

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
Set-Location Araiza/s3
Set-ExecutionPolicy -Scope Process Bypass
```

Wait for `docker info` to report `linux`. Run all local commands in `Araiza/s3`. For a PR preview switch the Araiza checkout to its review branch before entering the directory.

**macOS Terminal**
```bash
open -a Docker
brew services start jenkins-lts
command -v java mvn git docker
/usr/libexec/java_home -V
git clone https://github.com/DevXOmar/Araiza.git
cd Araiza/s3
```

Use `curl` for `curl.exe`. The setup equivalents are `bash scripts/setup.sh`, `bash scripts/setup.sh --env-only` and `bash scripts/setup.sh --fetch-only`. Use [PowerShell for macOS](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-macos) for verification scripts. The Docker and kubectl commands are shared.

## Ports and expected URLs

| Service | Address |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose | `http://127.0.0.1:8183/` and `/lab/` for the database companion |
| Nagios | `http://127.0.0.1:8893/nagios/` |
| Minikube | NodePort `30103` or forwarded `http://127.0.0.1:8313/` |
| EC2 | `http://PUBLIC_IPV4:8080/` |

## Question 1 — Web application and MySQL

[compose.yaml](compose.yaml) runs the assigned WAR at `/` and the separately labeled companion WAR at `/lab/` in the same Tomcat service. The recruitment companion accepts a multipart resume and stores its UUID filename on `s3-resumes`. MySQL stores candidate application fields and the file key. Take DB and upload backups together. A process crash can leave an unreferenced upload, which you can reconcile against the DB. The companion uses a restricted SQL account and prepared statements, checks a real query, and returns 503 when the database is unreachable. The application and DB share `ors-net`, use `db` as the hostname and retain data in `s3-db-data`. The database has no host port.

**PowerShell**
```powershell
./scripts/setup.ps1
docker compose config --quiet
docker compose up -d --build --wait --wait-timeout 180
docker compose ps
curl.exe -fsS http://127.0.0.1:8183/lab/health
```

**Browser** Open `http://127.0.0.1:8183/` for the original Java home page and `http://127.0.0.1:8183/lab/` for the database-backed form. Use a new synthetic reference if `Lab-01` is already saved.

```powershell
$resume = [IO.Path]::GetTempFileName()
Set-Content -Path $resume -Encoding Ascii -Value 'Synthetic resume for Lab-01'
curl.exe -fsS -F 'reference=Lab-01' -F 'position=Analyst' -F "resume=@$resume" http://127.0.0.1:8183/lab/records
curl.exe -fsS 'http://127.0.0.1:8183/lab/resume?reference=Lab-01'
Remove-Item $resume
```

**PowerShell** Read the record, simulate loss of the DB, then recreate its container.

```powershell
curl.exe -fsS http://127.0.0.1:8183/lab/records
docker compose kill db
curl.exe -i --max-time 8 http://127.0.0.1:8183/lab/health
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
curl.exe -fsS http://127.0.0.1:8183/lab/records
```

Expect `database OK` at startup, the saved row, an HTTP 503 during the outage, and the same row after replacement. A duplicate reference returns 409. Repeat the resume GET and compare the same file contents. Use `docker compose logs --tail=60 db web` and verify the role/password from the original initialization if health fails.

Scale behind [Nginx](proxy.conf), which owns the host port. Both application replicas use the same DB.

```powershell
docker compose up -d --no-deps --scale web=2 web
docker compose ps web proxy
curl.exe -fsS http://127.0.0.1:8183/lab/records
```

## Question 2 — Jenkins Pipeline

**Jenkins GUI** Open `http://localhost:8080/`. Under **Manage Jenkins → Plugins → Available plugins**, install Git, GitHub, Pipeline, JUnit and Pipeline Stage View. Under **Manage Jenkins → Tools**, configure Git and name the JDK `JDK21` and Maven `Maven3`. For installed tools, uncheck automatic installation and select the home directory above `bin`. If Git needs an explicit executable, use the path found by `Get-Command git`. Restart Jenkins after system PATH changes.

Maven runs the test lifecycle. The assigned repository has no test classes. The [companion JUnit suite](companion/pom.xml) checks candidate input validation.

1. **New Item → s3-pipeline → Pipeline → OK**. Set **Pipeline → Definition → Pipeline script**. Paste [Jenkinsfile](Jenkinsfile), leave **Use Groovy Sandbox** checked, and save.
2. The baseline Git source is `https://github.com/ssvkotamraju/ORS.git`. The public HTTPS checkout needs no credential. For automatic webhook builds, edit the `SOURCE_URL` and `SOURCE_BRANCH` default values in the pasted script to point to your writable training fork and exact branch, and run once manually to register Git SCM.
   For a PR preview set the `LAB_BRANCH` default to `lab/nine-set-execution`. Use `main` after merge.
   The upstream has `main`. For the release-only drill fork it and create `release` on the fork before the first build. The Jenkinsfile defaults to `release`. For a baseline upstream build change the branch default to `main`.

3. **Configure → Build Triggers**. Enable **GitHub hook trigger for GITScm polling** for a webhook. Use **Poll SCM** with `H/5 * * * *` when the controller is local. Save and click **Build Now** to register Git SCM.
4. Inspect stages, **Build History → Console Output**, and download `ORS.war` from **Artifacts**.

5. Click **Build with Parameters**, enable `FAIL_TEST` and run. The deliberate lab JUnit assertion fails, Jenkins skips WAR build and archival, and **Test Result** shows the failure. Clear `FAIL_TEST` for the next green build.

For build notifications, read the success or failure description in **Build History**. To also send email, install [Mailer](https://plugins.jenkins.io/mailer/), configure and test SMTP under **Manage Jenkins → System → E-mail Notification**, and set **NOTIFY_TO** to your approved lab inbox. Set it in **Build with Parameters** for manual runs or edit its default for the webhook run. With a configured mail server, compare one green and one deliberate red build and check each corresponding email.

If using a push trigger, a writable fork is required. In its **Settings → Webhooks → Add webhook**, enter the controller's reachable HTTPS URL plus `/github-webhook/`, select **application/json** and **Just the push event**. Check **Recent Deliveries** and the Jenkins SCM poll log. An upstream repo owner would have to install a webhook on the upstream. Compare a push to the configured branch with a push to a different branch.

**Troubleshooting** Read the first error in Console Output. On Windows confirm that the Pipeline uses `bat` and check the exact Jenkins tool names. If Jenkins needs Docker, inspect **services.msc → Jenkins → Properties → Log On**. Test `docker version` from the actual agent. Use a trusted interactive agent with Docker Desktop access, or configure the service account's Docker access and restart it. A successful interactive PowerShell test only verifies the logged-in user's access.

## Question 3 — Minikube

Apply the provided [Deployment](k8s/deployment.yaml), [Service](k8s/service.yaml) and [namespace](k8s/namespace.yaml). This uses the actual Java image with startup, readiness and liveness probes.

**PowerShell**
```powershell
./scripts/setup.ps1
minikube start --driver=docker
minikube status
minikube image load araiza-s3:v1
kubectl --context minikube apply -f k8s/namespace.yaml
kubectl --context minikube -n araiza-s3 apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl --context minikube -n araiza-s3 rollout status deployment/araiza-s3 --timeout=240s
kubectl --context minikube -n araiza-s3 get 'deployment,pods,svc' -o wide
kubectl --context minikube -n araiza-s3 get endpointslices -l kubernetes.io/service-name=araiza-s3
minikube service araiza-s3 -n araiza-s3 --url
```

Expect 2 Ready Pods and endpoints. Keep the Minikube service tunnel open if the Docker driver starts one. Use its listed URL, or use port-forward in another terminal.

```powershell
kubectl --context minikube -n araiza-s3 port-forward service/araiza-s3 8313:8080
```

```powershell
curl.exe -fsS http://127.0.0.1:8313/
curl.exe -fsS http://127.0.0.1:8313/apply.jsp
```

**PowerShell** Scale manually to 5, inspect Pod names, delete one and verify that the replacement has a different name. Use a second PowerShell window. If the deleted Pod was selected by port-forward, rerun the forward command.

```powershell
kubectl --context minikube -n araiza-s3 scale deployment/araiza-s3 --replicas=5
kubectl --context minikube -n araiza-s3 rollout status deployment/araiza-s3 --timeout=240s
kubectl --context minikube -n araiza-s3 get pods -o wide
$pod = kubectl --context minikube -n araiza-s3 get pods -l app=araiza-s3 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s3 delete pod $pod
kubectl --context minikube -n araiza-s3 rollout status deployment/araiza-s3 --timeout=240s
kubectl --context minikube -n araiza-s3 get pods -o wide
```

**PowerShell** Roll to the second image, then roll back. The build adds a visible revision label to the same upstream application. Reopen the forward after each rollout and check `http://127.0.0.1:8313/revision/index.txt` for `v2` and then `v1`.

```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s3:v2 .
minikube image load araiza-s3:v2
kubectl --context minikube -n araiza-s3 set image deployment/araiza-s3 web=araiza-s3:v2
kubectl --context minikube -n araiza-s3 rollout status deployment/araiza-s3 --timeout=240s
kubectl --context minikube -n araiza-s3 rollout history deployment/araiza-s3
```

```powershell
kubectl --context minikube -n araiza-s3 rollout undo deployment/araiza-s3
kubectl --context minikube -n araiza-s3 rollout status deployment/araiza-s3 --timeout=240s
```

**Troubleshooting** Replace a failing image with the correct loaded tag. Check startup logs and last termination reason for a crashing Pod. In a Pending Pod's events look for scheduling errors and resource shortages.

```powershell
$pod = kubectl --context minikube -n araiza-s3 get pods -l app=araiza-s3 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s3 describe pod $pod
kubectl --context minikube -n araiza-s3 logs $pod -c web --tail=60
kubectl --context minikube -n araiza-s3 logs $pod -c web --previous
kubectl --context minikube -n araiza-s3 get events --sort-by=.lastTimestamp
```

## Question 4 — Nagios monitoring

The [Compose overlay](nagios/compose.yaml) applies [host and service definitions](nagios/lab.cfg) for the portal, database TCP port and Docker Linux metrics. The SQL health check also detects database query failures through the companion.  The unprivileged [metrics agent](nagios/metrics.py) reads Linux CPU, memory, disk and uptime. On Docker Desktop these are metrics from the Docker Linux VM and its filesystem. No Docker socket or privileged container is needed.

**PowerShell** Build the Java image and start the monitoring services. For WordPress, complete first-run browser setup before testing the portal.

```powershell
./scripts/setup.ps1
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring pull nagios metrics
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios sv status nagios
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios python3 /opt/lab/check_lab.py http proxy 80 / 1 3
```

**Browser** Open `http://127.0.0.1:8893/nagios/`. Use `nagiosadmin` and the password in your local `.env`. Check **Hosts**, **Services** and **Alert History**. CPU and memory use 75% WARNING and 90% CRITICAL. Disk uses 80%/95% used. Uptime warns below 120s and is critical below 30s. HTTP warns at 1s, becomes critical at 3s or on an error status. The dashboard and alert history record state changes. Outbound email is disabled.

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

## Question 5 — AWS Academy EC2

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
cd Araiza/s3
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

[deploy.sh](aws/deploy.sh) installs Java 21 and Maven, verifies the Apache Tomcat 9 archive checksum, builds `ORS.war` and places it at `/opt/araiza-s3-tomcat/webapps/ROOT.war`. The enabled systemd unit starts Tomcat at boot.

**Ubuntu EC2 terminal**
```bash
sudo systemctl is-enabled araiza-s3-tomcat
sudo systemctl status araiza-s3-tomcat --no-pager
sudo journalctl -u araiza-s3-tomcat -n 80 --no-pager
ls -l /opt/araiza-s3-tomcat/webapps
sudo ss -lnt
```

**Laptop browser** Open `http://PUBLIC_IPV4:8080/`.  If local curl works and external access times out, check public IPv4, the app port in the attached security group, subnet route and `sudo ufw status` in Ubuntu. If local curl fails, check listeners and server logs. For 404, check the context and whether `ROOT.war` deployed.

## Scenario answers

### Question 1

1. The running transaction rolls back if it has not committed. Retry using the same reference after checking whether the first submission succeeded.
2. Reattach `s3-db-data` and `s3-resumes`. Restore corresponding SQL and file backups if either volume was lost.
3. `ors-net` supplies stable service DNS and prevents unrelated containers from reaching the database by default.
4. Use the scoped MySQL account, private generated credentials and no published DB port. Rotate credentials in MySQL before changing the running application config.
5. Scale `web` with `docker compose up -d --no-deps --scale web=2 web`. Nginx routes traffic and all replicas see the same SQL data and upload volume.

### Question 2

1. The build log reports the Maven compiler error, offending file and line. The nonzero exit stops the job.
2. A failing test stops packaging and archiving. Inspect the lab JUnit report for the failing assertion.
3. Maven resolves the pinned dependencies and their transitives using the POM and caches the artifacts.
4. Create `release` in a writable fork and set that exact default branch and repository in Jenkins. Only matching SCM changes schedule builds.
5. CI verifies changes. Continuous Deployment promotes qualifying artifacts into an environment automatically.

### Question 3

1. The Service routes to other Ready Pods. The crashed request may need retrying and the unhealthy replica recovers or is replaced.
2. The ReplicaSet reconciles its desired count to actual running Pods.
3. Manual scaling uses a fixed count. HPA samples metrics and automatically changes that count within limits.
4. A Service name and IP persist while EndpointSlices update when Pods move.
5. Run `kubectl --context minikube -n araiza-s3 rollout undo deployment/araiza-s3` and verify the previous revision's responses.

### Question 4

1. The CPU agent samples Linux CPU counters. Values at or above 75% warn and at or above 90% become critical.
2. WARNING signals degradation. CRITICAL signals the higher resource threshold or a failed availability check.
3. Nagios checks the HTTP response and the companion's SQL health endpoint, even with the server reachable.
4. Active checks and new alerts stop until Nagios returns. The application stack can still run.
5. Compare Tomcat root, SQL health, DB port and service-name resolution. If the internal requests work, check the client path and proxy listener.

### Question 5

1. Check whether TCP 8080 is admitted from the test audience, then verify public IPv4, subnet route and the Tomcat listener.
2. Limit TCP 22 to administrators to reduce exposure to unsolicited logins.
3. The HTTP request fails and in-memory recruiter sessions can be lost. Committed data survives in independent storage.
4. Run more than one application instance, use health checks and shared durable state, and keep backups.
5. An ALB spreads peak hiring traffic and removes failed targets while other instances serve.

## Common failures and fixes

- **Port in use.** In PowerShell, run `Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 8080,8183,8893,8313 }`. Identify the PID with `Get-Process -Id PID` after replacing PID. For Docker use `docker ps --format "table {{.Names}}	{{.Ports}}"`. On macOS use `lsof -nP -iTCP -sTCP:LISTEN`. Change the matching local port in `.env` where permitted.
- **Missing WAR.** Run `./scripts/setup.ps1 -FetchOnly` and `mvn -B -ntp -f app/upstream/pom.xml clean test package`. Expect `app/upstream/target/ORS.war`. For failed dependency resolution use `mvn -U -e -f app/upstream/pom.xml clean package` and inspect the failing repository or proxy.
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
| Containers Q1 | Working page and health, saved record before and after DB replacement. |
| Jenkins Q2 | Console phases, branch or trigger and archived `ORS.war` with red and green runs. |
| Minikube Q3 | 2 and 5 Ready replicas, endpoints, a new Pod name and HTTP at v2 and restored v1. |
| Nagios Q4 | Verified configuration, active HTTP and DB services, CPU/memory/disk/uptime, CRITICAL and recovery. |
| EC2 Q5 | Public IPv4, matching inbound TCP 8080, local curl and external browser. |
