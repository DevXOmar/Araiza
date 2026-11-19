# Set 1 · E-Ticketing

Assigned source [`ssvkotamraju/E-ticketing`](https://github.com/ssvkotamraju/E-ticketing), default branch `main`. [Source lock](app/source.properties) pins [`5a9b500`](https://github.com/ssvkotamraju/E-ticketing/tree/5a9b5004a4031b6006d47e83e037c6d7aeceedbd). Bootstrap clones the pinned source to ignored `app/upstream`. The upstream has no license file, so its sources are fetched on demand. It contains JSP pages and a WAR POM with Servlet 4.0.1, JSP API 2.3.3 and JSTL 1.2. There are no upstream test classes or JDBC integration. A clean build produces `target/LibraryRegistration.war`. Tomcat 9 provides `javax.servlet` compatibility and serves this file as `ROOT.war` at `/`.

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
Set-Location Araiza/s1
Set-ExecutionPolicy -Scope Process Bypass
```

Wait for `docker info` to report `linux`. Run all local commands in `Araiza/s1`. For a PR preview switch the Araiza checkout to its review branch before entering the directory.

**macOS Terminal**
```bash
open -a Docker
brew services start jenkins-lts
command -v java mvn git docker
/usr/libexec/java_home -V
git clone https://github.com/DevXOmar/Araiza.git
cd Araiza/s1
```

Use `curl` for `curl.exe`. The setup equivalents are `bash scripts/setup.sh`, `bash scripts/setup.sh --env-only` and `bash scripts/setup.sh --fetch-only`. Use [PowerShell for macOS](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-macos) for verification scripts. The Docker and kubectl commands are shared.

## Ports and expected URLs

| Service | Address |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose | `http://127.0.0.1:80/`  |
| Nagios | `http://127.0.0.1:8891/nagios/` |
| Minikube | NodePort `30101` or forwarded `http://127.0.0.1:8311/` |
| EC2 | `http://PUBLIC_IPV4/` |

## Question 1 — WordPress and MySQL

[compose.yaml](compose.yaml) runs the official images. WordPress connects to `db:3306` with a matching database name and non-root user on `eticket-net`. MySQL uses `eticket-db-data` and has no published port. WordPress files use `s1-wp-data`.

**PowerShell**
```powershell
./scripts/setup.ps1 -EnvOnly
docker compose config --quiet
docker compose pull
docker compose up -d --wait --wait-timeout 180
docker compose ps
docker compose logs --tail=40 web db
```

**Browser** Open `http://127.0.0.1:80/wp-admin/install.php`. Select a language and set site title **E-Ticketing**, a private admin username and a strong password. Sign in, choose **Pages → Add New**, name it **Concert bookings**, enter **Concert seat reservations**, and publish. Open **View Page** to copy its actual local path. Plain permalinks look like `/?page_id=NUMBER`.

Insert a **Shortcode** block with `[lab_ticket_booking]`. While signed in reserve seat `A7` and repeat the submission. Expect a booking code, then **Seat already reserved**. The [booking plugin](wordpress/ticket-booking.php) writes each reservation to MySQL where a unique event-and-seat index prevents duplicate reservations.

After initial WordPress setup, scale behind [Nginx](proxy.conf). Only the proxy binds host port 80. Its upstream resolves all `web` replicas using Docker DNS. The replicas share WordPress files and salts.

```powershell
docker compose up -d --no-deps --scale web=2 web
docker compose ps web proxy
```

**PowerShell** Simulate a crash and recreate MySQL without removing the named volume. An HTTP error or temporary timeout is expected during the outage.

```powershell
docker compose kill db
curl.exe -i --max-time 8 http://127.0.0.1:80/
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
docker volume inspect eticket-db-data
```

**Browser** Reload the published page. **Concert seat reservations** should remain. Sign in and confirm A7 under **Saved seats**. For a DB connection error use `docker compose logs db web`, `docker compose ps` and `docker compose exec web getent hosts db`. Check the generated credentials against the ones used to initialize the volume.

## Question 2 — Jenkins Pipeline

**Jenkins GUI** Open `http://localhost:8080/`. Under **Manage Jenkins → Plugins → Available plugins**, install Git, GitHub, Pipeline, JUnit and Pipeline Stage View. Under **Manage Jenkins → Tools**, configure Git and name the JDK `JDK21` and Maven `Maven3`. For installed tools, uncheck automatic installation and select the home directory above `bin`. If Git needs an explicit executable, use the path found by `Get-Command git`. Restart Jenkins after system PATH changes.

Maven runs the test lifecycle. The assigned repository has no test classes. The separate [JUnit project](ci-tests/pom.xml) checks ticket code generation and seat validation. The booking plugin is checked with the browser exercise.

1. **New Item → s1-pipeline → Pipeline → OK**. Set **Pipeline → Definition → Pipeline script**. Paste [Jenkinsfile](Jenkinsfile), leave **Use Groovy Sandbox** checked, and save.
2. The baseline Git source is `https://github.com/ssvkotamraju/E-ticketing.git`. The public HTTPS checkout needs no credential. For automatic webhook builds, edit the `SOURCE_URL` and `SOURCE_BRANCH` default values in the pasted script to point to your writable training fork and exact branch, and run once manually to register Git SCM.
   For a PR preview set the `LAB_BRANCH` default to `lab/nine-set-execution`. Use `main` after merge.
   For production branch filtering, use an exact branch such as `production` and create it in your fork first.

3. **Configure → Build Triggers**. Enable **Poll SCM** at `H/5 * * * *` for recurring checks, or **GitHub hook trigger for GITScm polling** for push-only builds. Save and click **Build Now** to register Git SCM.
4. Inspect stages, **Build History → Console Output**, and download `LibraryRegistration.war` from **Artifacts**.

5. Click **Build with Parameters**, enable `FAIL_TEST` and run. The deliberate lab JUnit assertion fails, Jenkins skips WAR build and archival, and **Test Result** shows the failure. Clear `FAIL_TEST` for the next green build.

If using a push trigger, a writable fork is required. In its **Settings → Webhooks → Add webhook**, enter the controller's reachable HTTPS URL plus `/github-webhook/`, select **application/json** and **Just the push event**. Check **Recent Deliveries** and the Jenkins SCM poll log. An upstream repo owner would have to install a webhook on the upstream. Compare a push to the configured branch with a push to a different branch.

**Troubleshooting** Read the first error in Console Output. On Windows confirm that the Pipeline uses `bat` and check the exact Jenkins tool names. If Jenkins needs Docker, inspect **services.msc → Jenkins → Properties → Log On**. Test `docker version` from the actual agent. Use a trusted interactive agent with Docker Desktop access, or configure the service account's Docker access and restart it. A successful interactive PowerShell test only verifies the logged-in user's access.

## Question 3 — Minikube

Apply the provided [Deployment](k8s/deployment.yaml), [Service](k8s/service.yaml) and [namespace](k8s/namespace.yaml). This uses the actual Java image with startup, readiness and liveness probes.

**PowerShell**
```powershell
./scripts/setup.ps1
minikube start --driver=docker
minikube status
minikube image load araiza-s1:v1
kubectl --context minikube apply -f k8s/namespace.yaml
kubectl --context minikube -n araiza-s1 apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl --context minikube -n araiza-s1 rollout status deployment/araiza-s1 --timeout=240s
kubectl --context minikube -n araiza-s1 get 'deployment,pods,svc' -o wide
kubectl --context minikube -n araiza-s1 get endpointslices -l kubernetes.io/service-name=araiza-s1
minikube service araiza-s1 -n araiza-s1 --url
```

Expect 2 Ready Pods and endpoints. Keep the Minikube service tunnel open if the Docker driver starts one. Use its listed URL, or use port-forward in another terminal.

```powershell
kubectl --context minikube -n araiza-s1 port-forward service/araiza-s1 8311:8080
```

```powershell
curl.exe -fsS http://127.0.0.1:8311/
curl.exe -fsS http://127.0.0.1:8311/register.jsp
```

**PowerShell** Scale manually to 5, inspect Pod names, delete one and verify that the replacement has a different name. Use a second PowerShell window. If the deleted Pod was selected by port-forward, rerun the forward command.

```powershell
kubectl --context minikube -n araiza-s1 scale deployment/araiza-s1 --replicas=5
kubectl --context minikube -n araiza-s1 rollout status deployment/araiza-s1 --timeout=240s
kubectl --context minikube -n araiza-s1 get pods -o wide
$pod = kubectl --context minikube -n araiza-s1 get pods -l app=araiza-s1 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s1 delete pod $pod
kubectl --context minikube -n araiza-s1 rollout status deployment/araiza-s1 --timeout=240s
kubectl --context minikube -n araiza-s1 get pods -o wide
```

**PowerShell** Roll to the second image, then roll back. The build adds a visible revision label to the same upstream application. Reopen the forward after each rollout and check `http://127.0.0.1:8311/revision/index.txt` for `v2` and then `v1`.

```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s1:v2 .
minikube image load araiza-s1:v2
kubectl --context minikube -n araiza-s1 set image deployment/araiza-s1 web=araiza-s1:v2
kubectl --context minikube -n araiza-s1 rollout status deployment/araiza-s1 --timeout=240s
kubectl --context minikube -n araiza-s1 rollout history deployment/araiza-s1
```

```powershell
kubectl --context minikube -n araiza-s1 rollout undo deployment/araiza-s1
kubectl --context minikube -n araiza-s1 rollout status deployment/araiza-s1 --timeout=240s
```

**Troubleshooting** Replace a failing image with the correct loaded tag. Check startup logs and last termination reason for a crashing Pod. In a Pending Pod's events look for scheduling errors and resource shortages.

```powershell
$pod = kubectl --context minikube -n araiza-s1 get pods -l app=araiza-s1 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s1 describe pod $pod
kubectl --context minikube -n araiza-s1 logs $pod -c web --tail=60
kubectl --context minikube -n araiza-s1 logs $pod -c web --previous
kubectl --context minikube -n araiza-s1 get events --sort-by=.lastTimestamp
```

## Question 4 — Nagios monitoring

The [Compose overlay](nagios/compose.yaml) applies [host and service definitions](nagios/lab.cfg) for the portal, database TCP port and Docker Linux metrics. The monitoring overlay runs a separate assigned-WAR Tomcat instance for its own HTTP check.  The unprivileged [metrics agent](nagios/metrics.py) reads Linux CPU, memory, disk and uptime. On Docker Desktop these are metrics from the Docker Linux VM and its filesystem. No Docker socket or privileged container is needed.

**PowerShell** Build the Java image and start the monitoring services. For WordPress, complete first-run browser setup before testing the portal.

```powershell
./scripts/setup.ps1
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring pull nagios metrics
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios sv status nagios
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios python3 /opt/lab/check_lab.py http proxy 80 / 1 3
```

**Browser** Open `http://127.0.0.1:8891/nagios/`. Use `nagiosadmin` and the password in your local `.env`. Check **Hosts**, **Services** and **Alert History**. CPU and memory use 75% WARNING and 90% CRITICAL. Disk uses 80%/95% used. Uptime warns below 120s and is critical below 30s. HTTP warns at 1s, becomes critical at 3s or on an error status. The dashboard and alert history record state changes. Outbound email is disabled.

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

Allow inbound TCP 22 from **My IP** (/32) and TCP **80** from the examiner's IP or permitted audience.  Keep DB ports closed. Use only synthetic data. If a small VM runs out of build memory, use a lab-approved larger instance.

**PowerShell** Create a public Docker Hub repo named `araiza-s1`. Log in with an access token at the prompt and publish the image. Keep the token private.

```powershell
./scripts/setup.ps1 -FetchOnly
$hubUser = Read-Host 'Docker Hub username'
docker login --username $hubUser
docker buildx build --platform linux/amd64,linux/arm64 --target app -t "${hubUser}/araiza-s1:v1" --push .
docker logout
```

For Jenkins-based publishing, add **Username with password** under **Manage Jenkins → Credentials → System → Global → Add Credentials**. Use your Docker Hub username, access token, and ID `dockerhub-creds` for a credentials binding. The supplied CI job handles Maven. The manual publish above is sufficient for EC2.

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
cd Araiza/s1
bash aws/deploy.sh YOUR_DOCKERHUB_USER/araiza-s1:v1
curl -fsS http://127.0.0.1/
```

[deploy.sh](aws/deploy.sh) installs Docker and Git, builds the pinned WAR locally for evidence, then pulls your published Tomcat image, and maps EC2 port 80 to container port 8080. Docker starts at boot and the container has an `unless-stopped` policy.

**Ubuntu EC2 terminal**
```bash
sudo systemctl status docker --no-pager
sudo docker ps -a --filter name=araiza-s1-ec2
sudo docker port araiza-s1-ec2
sudo docker logs --tail=80 araiza-s1-ec2
sudo ss -lnt
```

**Laptop browser** Open `http://PUBLIC_IPV4/`.  If local curl works and external access times out, check public IPv4, the app port in the attached security group, subnet route and `sudo ufw status` in Ubuntu. If local curl fails, check listeners and server logs. For 404, check the context and whether `ROOT.war` deployed.

## Scenario answers

### Question 1

1. InnoDB rolls back uncommitted reservations. Committed seats survive. If the client lost the acknowledgment, look up the seat before retrying and let the unique seat constraint prevent duplicates.
2. Recreate MySQL with `eticket-db-data` and the original credentials. If that volume is lost, restore a database backup into a new instance.
3. The user-defined network provides DNS for `db` and isolates lab services from unrelated containers.
4. Generate passwords outside Git, keep `.env` private, and use the restricted WordPress account. Leave port 3306 unpublished. Use managed secrets for a shared deployment.
5. Use `docker compose up -d --no-deps --scale web=2 web` after WordPress setup. Nginx owns port 80 and balances requests to replicas using shared files and MySQL.

### Question 2

1. Open Jenkins Console Output. Maven reports the compiler error with its source file and line and returns a failing exit status.
2. Surefire exits nonzero. Jenkins marks the job failed and skips packaging and archiving. The controlled test flag demonstrates this path.
3. The POM records dependency versions. Maven resolves them and their transitive dependencies reproducibly.
4. Create `production` on a writable fork. Set the source URL and exact branch to that fork and `production`, and use the push webhook or Poll SCM.
5. CI builds and tests changes. Continuous Deployment releases each qualifying change automatically.

### Question 3

1. The Service drops the unready endpoint. A request in flight may fail. The kubelet restarts a crashed container and the ReplicaSet replaces a deleted Pod.
2. The Deployment controller manages ReplicaSets, which reconcile actual replicas to the desired count.
3. `kubectl scale` sets a fixed desired count. An HPA adjusts it using metrics within configured bounds.
4. The Service IP and DNS remain stable. The Service sends requests to Ready endpoints selected by label.
5. Run `kubectl --context minikube -n araiza-s1 rollout undo deployment/araiza-s1`, wait for rollout status, and confirm `v1` through the Service.

### Question 4

1. The agent samples CPU counters twice. Nagios compares the measured busy percentage with the configured 75% and 90% thresholds.
2. WARNING means the first threshold was exceeded. CRITICAL means the higher threshold or an availability condition was reached.
3. The active HTTP check inspects the status code and marks HTTP 500 CRITICAL even if the host is up.
4. Checks, dashboard updates and alert processing stop. An external monitor can detect that the Nagios endpoint is down.
5. Compare the named Tomcat HTTP, WordPress HTTP, and MySQL TCP services. Use Compose logs and `getent hosts db` inside the respective container to isolate DNS or networking.

### Question 5

1. Check TCP 80 on the instance's actual security group and source CIDR. Verify public IPv4 and that Docker maps 80 to Tomcat's 8080.
2. Limit port 22 to trusted addresses to reduce exposure to scanning and login attempts.
3. Requests fail until Tomcat is back. Sessions held in memory can be lost, while committed external data remains.
4. Run independent instances in different Availability Zones behind health checks and use durable shared data, backups, and a recovery plan.
5. An ALB distributes ticket traffic across healthy instances, routes around unhealthy targets and supports capacity growth during a sale.

## Common failures and fixes

- **Port in use.** In PowerShell, run `Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 8080,80,8891,8311 }`. Identify the PID with `Get-Process -Id PID` after replacing PID. For Docker use `docker ps --format "table {{.Names}}	{{.Ports}}"`. On macOS use `lsof -nP -iTCP -sTCP:LISTEN`. Change the matching local port in `.env` where permitted.
- **Missing WAR.** Run `./scripts/setup.ps1 -FetchOnly` and `mvn -B -ntp -f app/upstream/pom.xml clean test package`. Expect `app/upstream/target/LibraryRegistration.war`. For failed dependency resolution use `mvn -U -e -f app/upstream/pom.xml clean package` and inspect the failing repository or proxy.
- **Engine inactive.** Check `docker context ls` and `docker version`. Wait for the Linux engine. Check permission under the Jenkins agent user separately.
- **Database unhealthy.** Run `docker compose ps` and `docker compose logs --tail=80 web db`. Initialization uses credentials from the first boot of the named volume. Restore the original `.env` or rotate the database account explicitly.
- **No Nagios status.** Verify daemon status and config, then wait for the next active check. Include both Compose files when inspecting monitoring.

## Verify and clean up

**PowerShell** Run `./scripts/setup.ps1` first. Complete WordPress setup and replace NUMBER with your published page ID or supply its actual local path.

```powershell
./scripts/verify.ps1 -WordPressQuery '/?page_id=NUMBER' -WordPressMarker 'Concert seat reservations' -RecreateDatabase -Kubernetes
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
| EC2 Q5 | Public IPv4, matching inbound TCP 80, local curl and external browser. |
