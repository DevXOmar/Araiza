# Set 2 · Hospital Management System

Assigned source [`ssvkotamraju/HMS`](https://github.com/ssvkotamraju/HMS), default branch `main`. [Source lock](app/source.properties) pins [`ae8ce41`](https://github.com/ssvkotamraju/HMS/tree/ae8ce417ee4f806697107a0c3df3994cff51d637). Bootstrap clones the pinned source to ignored `app/upstream`. The upstream has no license file, so its sources are fetched on demand. It contains JSP pages and a WAR POM with Servlet 4.0.1, JSP API 2.3.3 and JSTL 1.2. There are no upstream test classes or JDBC integration. A clean build produces `target/LibraryRegistration.war`. Tomcat 9 provides `javax.servlet` compatibility and serves this file as `ROOT.war` at `/`.

The upstream Dockerfile uses Tomcat 9 and copies `target/*.war`. This set builds from clean source and copies `LibraryRegistration.war` by name. The upstream Compose file references the wrong WAR and an absent SQL initializer.

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
Set-Location Araiza/s2
Set-ExecutionPolicy -Scope Process Bypass
```

Wait for `docker info` to report `linux`. Run all local commands in `Araiza/s2`. For a PR preview switch the Araiza checkout to its review branch before entering the directory.

**macOS Terminal**
```bash
open -a Docker
brew services start jenkins-lts
command -v java mvn git docker
/usr/libexec/java_home -V
git clone https://github.com/DevXOmar/Araiza.git
cd Araiza/s2
```

Use `curl` for `curl.exe`. The setup equivalents are `bash scripts/setup.sh`, `bash scripts/setup.sh --env-only` and `bash scripts/setup.sh --fetch-only`. Use [PowerShell for macOS](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-macos) for verification scripts. The Docker and kubectl commands are shared.

## Ports and expected URLs

| Service | Address |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose | `http://127.0.0.1:8182/` and `/lab/` for the database companion |
| Nagios | `http://127.0.0.1:8892/nagios/` |
| Minikube | NodePort `30102` or forwarded `http://127.0.0.1:8312/` |
| EC2 | `http://PUBLIC_IPV4:8080/` |

## Question 1 — Web application and PostgreSQL 15

[compose.yaml](compose.yaml) runs the assigned WAR at `/` and the separately labeled companion WAR at `/lab/` in the same Tomcat service. The HMS companion stores synthetic appointment references and departments. The companion uses a restricted SQL account and prepared statements, checks a real query, and returns 503 when the database is unreachable. The application and DB share `hms-net`, use `db` as the hostname and retain data in `s2-db-data`. The database has no host port.

**PowerShell**
```powershell
./scripts/setup.ps1
docker compose config --quiet
docker compose up -d --build --wait --wait-timeout 180
docker compose ps
curl.exe -fsS http://127.0.0.1:8182/lab/health
```

**Browser** Open `http://127.0.0.1:8182/` for the original Java home page and `http://127.0.0.1:8182/lab/` for the database-backed form. Use a new synthetic reference if `Lab-01` is already saved.

```powershell
curl.exe -fsS -d 'reference=Lab-01' --data-urlencode 'department=General' http://127.0.0.1:8182/lab/records
```

**PowerShell** Read the record, simulate loss of the DB, then recreate its container.

```powershell
curl.exe -fsS http://127.0.0.1:8182/lab/records
docker compose kill db
curl.exe -i --max-time 8 http://127.0.0.1:8182/lab/health
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
curl.exe -fsS http://127.0.0.1:8182/lab/records
```

Expect `database OK` at startup, the saved row, an HTTP 503 during the outage, and the same row after replacement. A duplicate reference returns 409.  Use `docker compose logs --tail=60 db web` and verify the role/password from the original initialization if health fails.

Scale behind [Nginx](proxy.conf), which owns the host port. Both application replicas use the same DB.

```powershell
docker compose up -d --no-deps --scale web=2 web
docker compose ps web proxy
curl.exe -fsS http://127.0.0.1:8182/lab/records
```

## Question 2 — Jenkins Pipeline

**Jenkins GUI** Open `http://localhost:8080/`. Under **Manage Jenkins → Plugins → Available plugins**, install Git, GitHub, Pipeline, JUnit and Pipeline Stage View. Under **Manage Jenkins → Tools**, configure Git and name the JDK `JDK21` and Maven `Maven3`. For installed tools, uncheck automatic installation and select the home directory above `bin`. If Git needs an explicit executable, use the path found by `Get-Command git`. Restart Jenkins after system PATH changes.

Maven runs the test lifecycle. The assigned repository has no test classes. The [companion JUnit suite](companion/pom.xml) checks appointment input validation.

1. **New Item → s2-pipeline → Pipeline → OK**. Set **Pipeline → Definition → Pipeline script**. Paste [Jenkinsfile](Jenkinsfile), leave **Use Groovy Sandbox** checked, and save.
2. The baseline Git source is `https://github.com/ssvkotamraju/HMS.git`. The public HTTPS checkout needs no credential. For automatic webhook builds, edit the `SOURCE_URL` and `SOURCE_BRANCH` default values in the pasted script to point to your writable training fork and exact branch, and run once manually to register Git SCM.
   For a PR preview set the `LAB_BRANCH` default to `lab/nine-set-execution`. Use `main` after merge.

3. **Configure → Build Triggers**. Enable **GitHub hook trigger for GITScm polling** for a webhook. Use **Poll SCM** with `H/5 * * * *` when the controller is local. Save and click **Build Now** to register Git SCM.
4. Inspect stages, **Build History → Console Output**, and download `LibraryRegistration.war` from **Artifacts**.

5. Click **Build with Parameters**, enable `FAIL_TEST` and run. The deliberate lab JUnit assertion fails, Jenkins skips WAR build and archival, and **Test Result** shows the failure. Clear `FAIL_TEST` for the next green build.

If using a push trigger, a writable fork is required. In its **Settings → Webhooks → Add webhook**, enter the controller's reachable HTTPS URL plus `/github-webhook/`, select **application/json** and **Just the push event**. Check **Recent Deliveries** and the Jenkins SCM poll log. An upstream repo owner would have to install a webhook on the upstream. Compare a push to the configured branch with a push to a different branch.

### Build only pull requests targeting main

Create a separate Pipeline job `s2-hms-main-pr`. Install [Generic Webhook Trigger](https://plugins.jenkins.io/generic-webhook-trigger/). Add an isolated Jenkins agent with label `pr-isolated` and configured Maven, Git and JDK. Use a training fork with vetted contributors and keep Docker and cloud credentials off this agent.

1. Paste [Jenkinsfile.pr](Jenkinsfile.pr) as the Pipeline script and change its repository constant to your HMS fork URL. Under **Manage Jenkins → Credentials → Global → Add Credentials**, add a random **Secret text** value with ID `s2-pr-webhook-token`.
2. Under job **Configure → Build Triggers → Generic Webhook Trigger**, select that **Token Credential**. Define **Post content parameters** with JSONPath.

   | Variable | JSONPath |
   | --- | --- |
   | `PR_BASE` | `$.pull_request.base.ref` |
   | `PR_NUMBER` | `$.number` |
   | `PR_ACTION` | `$.action` |
   | `PR_REPO` | `$.repository.full_name` |

3. Set **Optional filter text** to `$PR_REPO:$PR_BASE:$PR_ACTION` and **expression** to `^YOUR_GITHUB_OWNER/HMS:main:(opened|reopened|synchronize|ready_for_review)$`, using your fork's exact owner and name. Leave payload printing and branch push triggers off.
4. Add a GitHub JSON webhook for **Pull requests** only, with payload URL `https://YOUR_JENKINS/generic-webhook-trigger/invoke?token=YOUR_RANDOM_TOKEN`. Insert the credential value privately and omit it from screenshots and source.
5. Compare a PR into `main` with one into another branch. Only the matching event schedules a build. The Pipeline fetches the PR merge ref, which GitHub creates when the PR is mergeable.

**Troubleshooting** Read the first error in Console Output. On Windows confirm that the Pipeline uses `bat` and check the exact Jenkins tool names. If Jenkins needs Docker, inspect **services.msc → Jenkins → Properties → Log On**. Test `docker version` from the actual agent. Use a trusted interactive agent with Docker Desktop access, or configure the service account's Docker access and restart it. A successful interactive PowerShell test only verifies the logged-in user's access.

## Question 3 — Minikube

Apply the provided [Deployment](k8s/deployment.yaml), [Service](k8s/service.yaml) and [namespace](k8s/namespace.yaml). This uses the actual Java image with startup, readiness and liveness probes.

**PowerShell**
```powershell
./scripts/setup.ps1
minikube start --driver=docker
minikube status
minikube image load araiza-s2:v1
kubectl --context minikube apply -f k8s/namespace.yaml
kubectl --context minikube -n araiza-s2 apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl --context minikube -n araiza-s2 rollout status deployment/araiza-s2 --timeout=240s
kubectl --context minikube -n araiza-s2 get 'deployment,pods,svc' -o wide
kubectl --context minikube -n araiza-s2 get endpointslices -l kubernetes.io/service-name=araiza-s2
minikube service araiza-s2 -n araiza-s2 --url
```

Expect 2 Ready Pods and endpoints. Keep the Minikube service tunnel open if the Docker driver starts one. Use its listed URL, or use port-forward in another terminal.

```powershell
kubectl --context minikube -n araiza-s2 port-forward service/araiza-s2 8312:8080
```

```powershell
curl.exe -fsS http://127.0.0.1:8312/
curl.exe -fsS http://127.0.0.1:8312/register.jsp
```

**PowerShell** Scale manually to 5, inspect Pod names, delete one and verify that the replacement has a different name. Use a second PowerShell window. If the deleted Pod was selected by port-forward, rerun the forward command.

```powershell
kubectl --context minikube -n araiza-s2 scale deployment/araiza-s2 --replicas=5
kubectl --context minikube -n araiza-s2 rollout status deployment/araiza-s2 --timeout=240s
kubectl --context minikube -n araiza-s2 get pods -o wide
$pod = kubectl --context minikube -n araiza-s2 get pods -l app=araiza-s2 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s2 delete pod $pod
kubectl --context minikube -n araiza-s2 rollout status deployment/araiza-s2 --timeout=240s
kubectl --context minikube -n araiza-s2 get pods -o wide
```

**PowerShell** Roll to the second image, then roll back. The build adds a visible revision label to the same upstream application. Reopen the forward after each rollout and check `http://127.0.0.1:8312/revision/index.txt` for `v2` and then `v1`.

```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s2:v2 .
minikube image load araiza-s2:v2
kubectl --context minikube -n araiza-s2 set image deployment/araiza-s2 web=araiza-s2:v2
kubectl --context minikube -n araiza-s2 rollout status deployment/araiza-s2 --timeout=240s
kubectl --context minikube -n araiza-s2 rollout history deployment/araiza-s2
```

```powershell
kubectl --context minikube -n araiza-s2 rollout undo deployment/araiza-s2
kubectl --context minikube -n araiza-s2 rollout status deployment/araiza-s2 --timeout=240s
```

**LoadBalancer and HPA** Patch to LoadBalancer and start `minikube tunnel` from a separate terminal if using that mode. Read the assigned address with `kubectl get svc` and use port 8080. For actual HPA, metrics-server must report CPU usage. This HPA targets 60% of requested CPU across 2–5 replicas. Delete it before returning to manual scaling.

```powershell
kubectl --context minikube -n araiza-s2 patch service araiza-s2 --type=merge --patch-file k8s/loadbalancer-patch.yaml
minikube addons enable metrics-server
kubectl --context minikube -n araiza-s2 apply -f k8s/hpa.yaml
kubectl --context minikube -n araiza-s2 get hpa
kubectl --context minikube -n araiza-s2 delete hpa araiza-s2
kubectl --context minikube -n araiza-s2 apply -f k8s/service.yaml
```

**Troubleshooting** Replace a failing image with the correct loaded tag. Check startup logs and last termination reason for a crashing Pod. In a Pending Pod's events look for scheduling errors and resource shortages.

```powershell
$pod = kubectl --context minikube -n araiza-s2 get pods -l app=araiza-s2 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s2 describe pod $pod
kubectl --context minikube -n araiza-s2 logs $pod -c web --tail=60
kubectl --context minikube -n araiza-s2 logs $pod -c web --previous
kubectl --context minikube -n araiza-s2 get events --sort-by=.lastTimestamp
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

**Browser** Open `http://127.0.0.1:8892/nagios/`. Use `nagiosadmin` and the password in your local `.env`. Check **Hosts**, **Services** and **Alert History**. CPU and memory use 65% WARNING and 85% CRITICAL. Disk uses 80%/95% used. Uptime warns below 120s and is critical below 30s. HTTP warns at 1s, becomes critical at 3s or on an error status. The dashboard and alert history record state changes. Outbound email is disabled.

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
cd Araiza/s2
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

[deploy.sh](aws/deploy.sh) installs Java 21 and Maven, verifies the Apache Tomcat 9 archive checksum, builds `LibraryRegistration.war` and places it at `/opt/araiza-s2-tomcat/webapps/ROOT.war`. The enabled systemd unit starts Tomcat at boot.

**Ubuntu EC2 terminal**
```bash
sudo systemctl is-enabled araiza-s2-tomcat
sudo systemctl status araiza-s2-tomcat --no-pager
sudo journalctl -u araiza-s2-tomcat -n 80 --no-pager
ls -l /opt/araiza-s2-tomcat/webapps
sudo ss -lnt
```

The HMS deployment also initializes local PostgreSQL and deploys the companion. The loopback JDBC URL, role and generated password are in root-only `/etc/araiza-s2-db.env`.

**Ubuntu EC2 terminal**
```bash
curl -fsS http://127.0.0.1:8080/lab/health
curl -fsS -d 'reference=Ec2-Demo-01&department=General' http://127.0.0.1:8080/lab/records
curl -fsS http://127.0.0.1:8080/lab/records
sudo -u postgres psql -d hms -c 'SELECT reference, department FROM appointments;'
```

In **EC2 → Instances → Monitoring**, check CPU and status checks. In **CloudWatch → Metrics → All metrics → EC2 → Per-Instance Metrics**, filter by your instance ID and graph `CPUUtilization` and `StatusCheckFailed` over a range that includes startup. Basic metrics require no agent. Guest memory and filesystem metrics require the CloudWatch Agent and an Academy-approved IAM role.

**Laptop browser** Open `http://PUBLIC_IPV4:8080/`.  If local curl works and external access times out, check public IPv4, the app port in the attached security group, subnet route and `sudo ufw status` in Ubuntu. If local curl fails, check listeners and server logs. For 404, check the context and whether `ROOT.war` deployed.

## Scenario answers

### Question 1

1. An unfinished prescription transaction rolls back. A committed update persists, so verify its state before resubmitting after reconnection.
2. Attach `s2-db-data` to the replacement PostgreSQL container. Restore an authorized backup if the volume was also lost.
3. `hms-net` limits container exposure and gives the HMS service stable DNS for the database.
4. Keep PostgreSQL unpublished, limit network membership, and use the scoped role with a private generated password.
5. Scale web behind Nginx with `docker compose up -d --no-deps --scale web=2 web`. For department segregation use separately authorized routes, identities and data access policies.

### Question 2

1. Read Console Output for Maven compiler diagnostics and the source file and line. A nonzero exit fails the build.
2. A failed validation assertion blocks subsequent Maven packaging and WAR archival. Jenkins keeps the lab JUnit report for diagnosis.
3. Maven records versions centrally and resolves transitive dependencies consistently on each agent.
4. Use the separate PR job. Filter the webhook before scheduling on PR action and `$.pull_request.base.ref=main`, then build the numbered merge ref.
5. CI compiles and tests clinical software. Continuous Deployment automatically releases qualifying changes, where policy permits.

### Question 3

1. The affected request may fail. The Service removes the unavailable Pod from Ready endpoints while Kubernetes recovers it.
2. The Deployment maintains a ReplicaSet whose controller reconciles Pods to the requested count.
3. Manual scaling writes a replica count. The provided optional HPA reads CPU metrics from metrics-server and varies the count from 2 to 5.
4. A Service gives clients stable DNS and forwards to Ready Pods as their IP addresses change.
5. Run `kubectl --context minikube -n araiza-s2 rollout undo deployment/araiza-s2`, then confirm rollout and verify HTTP.

### Question 4

1. The metric uses `MemAvailable` and `MemTotal` to estimate memory pressure and compares it with 65% and 85%.
2. WARNING merits investigation. CRITICAL warrants immediate response according to the service's incident priority.
3. The companion's `/lab/health` executes a SQL query and returns 503 on failure. This can happen with a healthy host or open DB port.
4. The Nagios instance ceases checking and processing alerts. Use an independent endpoint check to detect the monitor failure.
5. Compare root HTTP, the SQL round trip, and DB TCP. If internal checks pass and external access fails, check client paths, DNS and routing.

### Question 5

1. Confirm the public IP, the attached security group and its TCP 8080 source range, and the route from the client. Compare them with a successful local curl.
2. Restrict port 22 to the admin's IP to limit login attempts and reduce exposure.
3. In-flight requests are interrupted. In-memory sessions can be lost. PostgreSQL retains committed records.
4. Use tested DB backups and failover, multiple application instances across zones, and externalized state where required.
5. An ALB sends traffic to healthy instances and enables rolling replacement or scale-out without depending on one VM.

## Common failures and fixes

- **Port in use.** In PowerShell, run `Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 8080,8182,8892,8312 }`. Identify the PID with `Get-Process -Id PID` after replacing PID. For Docker use `docker ps --format "table {{.Names}}	{{.Ports}}"`. On macOS use `lsof -nP -iTCP -sTCP:LISTEN`. Change the matching local port in `.env` where permitted.
- **Missing WAR.** Run `./scripts/setup.ps1 -FetchOnly` and `mvn -B -ntp -f app/upstream/pom.xml clean test package`. Expect `app/upstream/target/LibraryRegistration.war`. For failed dependency resolution use `mvn -U -e -f app/upstream/pom.xml clean package` and inspect the failing repository or proxy.
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
| Jenkins Q2 | Console phases, branch or trigger and archived `LibraryRegistration.war` with red and green runs. |
| Minikube Q3 | 2 and 5 Ready replicas, endpoints, a new Pod name and HTTP at v2 and restored v1. |
| Nagios Q4 | Verified configuration, active HTTP and DB services, CPU/memory/disk/uptime, CRITICAL and recovery. |
| EC2 Q5 | Public IPv4, matching inbound TCP 8080, local curl and external browser plus CloudWatch graph. |
