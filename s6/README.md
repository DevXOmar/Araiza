# Set 6 · Vehicle Rental Management System

Assigned source [`nikithamoturi/VehicleRentalManagementSystem`](https://github.com/nikithamoturi/VehicleRentalManagementSystem), default branch `main`. [Source lock](app/source.properties) pins [`7d29e04`](https://github.com/nikithamoturi/VehicleRentalManagementSystem/tree/7d29e04094a92d86470629c14de5620c11fe07eb). Bootstrap clones the pinned source to ignored `app/upstream`. The upstream has no license file, so its sources are fetched on demand. It contains JSP pages and a WAR POM with Servlet 4.0.1 and JUnit 4.13.1. There are no upstream test classes or JDBC integration. A clean build produces `target/VehicleRentalManagement.war`. Tomcat 9 provides `javax.servlet` compatibility and serves this file as `ROOT.war` at `/`.

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
Set-Location Araiza/s6
Set-ExecutionPolicy -Scope Process Bypass
```

Wait for `docker info` to report `linux`. Run all local commands in `Araiza/s6`. For a PR preview switch the Araiza checkout to its review branch before entering the directory.

**macOS Terminal**
```bash
open -a Docker
brew services start jenkins-lts
command -v java mvn git docker
/usr/libexec/java_home -V
git clone https://github.com/DevXOmar/Araiza.git
cd Araiza/s6
```

Use `curl` for `curl.exe`. The setup equivalents are `bash scripts/setup.sh`, `bash scripts/setup.sh --env-only` and `bash scripts/setup.sh --fetch-only`. Use [PowerShell for macOS](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-macos) for verification scripts. The Docker and kubectl commands are shared.

## Ports and expected URLs

| Service | Address |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose | `http://127.0.0.1:8186/`  |
| Nagios | `http://127.0.0.1:8896/nagios/` |
| Minikube | NodePort `30106` or forwarded `http://127.0.0.1:8316/` |
| EC2 | `http://PUBLIC_IPV4:8080/` |

## Question 1 — WordPress and MySQL

[compose.yaml](compose.yaml) runs the official images. WordPress connects to `db:3306` with a matching database name and non-root user on `s6-data-net`. MySQL uses `s6-db-data` and has no published port. WordPress files use `s6-wp-data`.

This information portal is independent of the assigned Java project. The Java source is used for Jenkins, Kubernetes, Tomcat monitoring and EC2.

**PowerShell**
```powershell
./scripts/setup.ps1 -EnvOnly
docker compose config --quiet
docker compose pull
docker compose up -d --wait --wait-timeout 180
docker compose ps
docker compose logs --tail=40 web db
```

**Browser** Open `http://127.0.0.1:8186/wp-admin/install.php`. Select a language and set site title **Vehicle rental information**, a private admin username and a strong password. Sign in, choose **Pages → Add New**, name it **Vehicles and rental policies**, enter **Airport pickup and compact car rentals**, and publish. Open **View Page** to copy its actual local path. Plain permalinks look like `/?page_id=NUMBER`.

**PowerShell** Simulate a crash and recreate MySQL without removing the named volume. An HTTP error or temporary timeout is expected during the outage.

```powershell
docker compose kill db
curl.exe -i --max-time 8 http://127.0.0.1:8186/
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
docker volume inspect s6-db-data
```

**Browser** Reload the published page. **Airport pickup and compact car rentals** should remain.  For a DB connection error use `docker compose logs db web`, `docker compose ps` and `docker compose exec web getent hosts db`. Check the generated credentials against the ones used to initialize the volume.

## Question 2 — Jenkins Freestyle

**Jenkins GUI** Open `http://localhost:8080/`. Under **Manage Jenkins → Plugins → Available plugins**, install Git, GitHub and Maven Integration. Under **Manage Jenkins → Tools**, configure Git and name the JDK `JDK21` and Maven `Maven3`. For installed tools, uncheck automatic installation and select the home directory above `bin`. If Git needs an explicit executable, use the path found by `Get-Command git`. Restart Jenkins after system PATH changes.

Maven runs the test lifecycle. The assigned repository has no test classes. The console may show **No tests to run**. Capture that output alongside the WAR.

1. **New Item → s6-freestyle → Freestyle project → OK**.
2. Under **General**, choose `JDK21` if shown. Under **Source Code Management → Git**, use `https://github.com/nikithamoturi/VehicleRentalManagementSystem.git`, **Credentials → None** and **Branch Specifier → `*/main`**. For a feature branch, use your fork URL and an exact specifier such as `*/feature/cart`.
3. Under **Build Triggers**, check **Poll SCM** and enter `H/5 * * * *`. Alternatively enable **GitHub hook trigger for GITScm polling** and configure the writable fork's webhook.
4. Under **Build Steps → Invoke top-level Maven targets**, choose `Maven3` and enter goals `clean test package`. Leave POM blank because `pom.xml` is at the checkout root.
5. Under **Post-build Actions → Archive the artifacts**, set `target/VehicleRentalManagement.war`. Enable fingerprinting and success-only archiving.
6. To demonstrate a red build safely, add `-Dtest=MissingLabTest -Dsurefire.failIfNoSpecifiedTests=true` to the goals. Save and click **Build Now**. Expect Surefire's matching-test error. Restore `clean test package`, save and run again. In **Build History → Console Output** confirm success and download `VehicleRentalManagement.war` under **Artifacts**.

If using a push trigger, a writable fork is required. In its **Settings → Webhooks → Add webhook**, enter the controller's reachable HTTPS URL plus `/github-webhook/`, select **application/json** and **Just the push event**. Check **Recent Deliveries** and the Jenkins SCM poll log. An upstream repo owner would have to install a webhook on the upstream. Compare a push to the configured branch with a push to a different branch.

**Troubleshooting** Read the first error in Console Output. On Windows confirm that the Pipeline uses `bat` and check the exact Jenkins tool names. If Jenkins needs Docker, inspect **services.msc → Jenkins → Properties → Log On**. Test `docker version` from the actual agent. Use a trusted interactive agent with Docker Desktop access, or configure the service account's Docker access and restart it. A successful interactive PowerShell test only verifies the logged-in user's access.

## Question 3 — Minikube

Apply the provided [Deployment](k8s/deployment.yaml), [Service](k8s/service.yaml) and [namespace](k8s/namespace.yaml). This uses the actual Java image with startup, readiness and liveness probes.

**PowerShell**
```powershell
./scripts/setup.ps1
minikube start --driver=docker
minikube status
minikube image load araiza-s6:v1
kubectl --context minikube apply -f k8s/namespace.yaml
kubectl --context minikube -n araiza-s6 apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl --context minikube -n araiza-s6 rollout status deployment/araiza-s6 --timeout=240s
kubectl --context minikube -n araiza-s6 get 'deployment,pods,svc' -o wide
kubectl --context minikube -n araiza-s6 get endpointslices -l kubernetes.io/service-name=araiza-s6
minikube service araiza-s6 -n araiza-s6 --url
```

Expect 2 Ready Pods and endpoints. Keep the Minikube service tunnel open if the Docker driver starts one. Use its listed URL, or use port-forward in another terminal.

```powershell
kubectl --context minikube -n araiza-s6 port-forward service/araiza-s6 8316:8080
```

```powershell
curl.exe -fsS http://127.0.0.1:8316/
curl.exe -fsS http://127.0.0.1:8316/vehicle.jsp
```

**PowerShell** Scale manually to 4, inspect Pod names, delete one and verify that the replacement has a different name. Use a second PowerShell window. If the deleted Pod was selected by port-forward, rerun the forward command.

```powershell
kubectl --context minikube -n araiza-s6 scale deployment/araiza-s6 --replicas=4
kubectl --context minikube -n araiza-s6 rollout status deployment/araiza-s6 --timeout=240s
kubectl --context minikube -n araiza-s6 get pods -o wide
$pod = kubectl --context minikube -n araiza-s6 get pods -l app=araiza-s6 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s6 delete pod $pod
kubectl --context minikube -n araiza-s6 rollout status deployment/araiza-s6 --timeout=240s
kubectl --context minikube -n araiza-s6 get pods -o wide
```

**PowerShell** Roll to the second image, then roll back. The build adds a visible revision label to the same upstream application. Reopen the forward after each rollout and check `http://127.0.0.1:8316/revision/index.txt` for `v2` and then `v1`.

```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s6:v2 .
minikube image load araiza-s6:v2
kubectl --context minikube -n araiza-s6 set image deployment/araiza-s6 web=araiza-s6:v2
kubectl --context minikube -n araiza-s6 rollout status deployment/araiza-s6 --timeout=240s
kubectl --context minikube -n araiza-s6 rollout history deployment/araiza-s6
```

```powershell
kubectl --context minikube -n araiza-s6 rollout undo deployment/araiza-s6
kubectl --context minikube -n araiza-s6 rollout status deployment/araiza-s6 --timeout=240s
```

**Failed update drill** Use a deliberately missing tag. Wait for a rollout timeout, inspect events, and roll back to the locally loaded image.

```powershell
kubectl --context minikube -n araiza-s6 set image deployment/araiza-s6 web=araiza-s6:missing-drill
kubectl --context minikube -n araiza-s6 rollout status deployment/araiza-s6 --timeout=45s
kubectl --context minikube -n araiza-s6 get events --sort-by=.lastTimestamp
kubectl --context minikube -n araiza-s6 rollout undo deployment/araiza-s6
kubectl --context minikube -n araiza-s6 rollout status deployment/araiza-s6 --timeout=240s
```

**Troubleshooting** Replace a failing image with the correct loaded tag. Check startup logs and last termination reason for a crashing Pod. In a Pending Pod's events look for scheduling errors and resource shortages.

```powershell
$pod = kubectl --context minikube -n araiza-s6 get pods -l app=araiza-s6 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s6 describe pod $pod
kubectl --context minikube -n araiza-s6 logs $pod -c web --tail=60
kubectl --context minikube -n araiza-s6 logs $pod -c web --previous
kubectl --context minikube -n araiza-s6 get events --sort-by=.lastTimestamp
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
docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios python3 /opt/lab/check_lab.py http web 80 / 1 3
```

**Browser** Open `http://127.0.0.1:8896/nagios/`. Use `nagiosadmin` and the password in your local `.env`. Check **Hosts**, **Services** and **Alert History**. CPU and memory use 75% WARNING and 90% CRITICAL. Disk uses 80%/95% used. Uptime warns below 120s and is critical below 30s. HTTP warns at 1s, becomes critical at 3s or on an error status. The dashboard and alert history record state changes. Outbound email is disabled.

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
cd Araiza/s6
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

[deploy.sh](aws/deploy.sh) installs Java 21 and Maven, verifies the Apache Tomcat 9 archive checksum, builds `VehicleRentalManagement.war` and places it at `/opt/araiza-s6-tomcat/webapps/ROOT.war`. The enabled systemd unit starts Tomcat at boot.

**Ubuntu EC2 terminal**
```bash
sudo systemctl is-enabled araiza-s6-tomcat
sudo systemctl status araiza-s6-tomcat --no-pager
sudo journalctl -u araiza-s6-tomcat -n 80 --no-pager
ls -l /opt/araiza-s6-tomcat/webapps
sudo ss -lnt
```

**Laptop browser** Open `http://PUBLIC_IPV4:8080/`.  If local curl works and external access times out, check public IPv4, the app port in the attached security group, subnet route and `sudo ufw status` in Ubuntu. If local curl fails, check listeners and server logs. For 404, check the context and whether `ROOT.war` deployed.

## Scenario answers

### Question 1

1. WordPress may report a database connection error during MySQL initialization. The Compose health gate waits for an authenticated SELECT.
2. Both services share the data network. The name `db` resolves to the current MySQL container address.
3. MySQL checks the configured account and database on connection. A mismatch fails authentication or schema selection.
4. Edit `WEB_PORT` in `.env`, apply Compose again and open the new local address. Leave container port 80 unchanged.
5. Compose attaches `s6-db-data` to the replacement and preserves its SQL files.

### Question 2

1. Jenkins runs Maven after checking out the branch so it reports compilation or test failures on the originating build.
2. Inspect the failing coordinates and repository in Console Output. Check the version, internet connection, mirror and proxy settings. Try Maven with `-U -e`.
3. Tests detect regressions before a WAR is shipped. The assigned JSP project has no tests, so use the documented reversible Maven failure demonstration.
4. Point Git SCM to the correct fork and use the exact branch specifier such as `*/feature/vehicles`.
5. A retained WAR can be traced to its successful build and reused for deployment or rollback.

### Question 3

1. The controller replaces the terminated Pod. The Service continues routing to available replicas.
2. The replica count is the desired number of Pods maintained by the ReplicaSet.
3. Scaling increases capacity during holiday demand, subject to resource and dependency constraints.
4. The Service address persists while EndpointSlices are updated for new Pod addresses.
5. Inspect `get events` and `rollout status` for pull or readiness failures, run `kubectl --context minikube -n araiza-s6 rollout undo deployment/araiza-s6` and verify HTTP.

### Question 4

1. Compare CPU, memory, disk and uptime service results before demand causes application failures.
2. WARNING marks the first threshold. CRITICAL marks a severe threshold or an unavailable endpoint.
3. Reachable hosts can return HTTP 500 or an excessive response time. The HTTP plugin tests the endpoint itself.
4. No new measurements, transitions or recovery records are available from that Nagios server.
5. Use the Tomcat and portal HTTP checks, MySQL TCP and Compose logs. If local service tests succeed and host access fails, examine mappings and routing.

### Question 5

1. Check whether TCP 8080 is open to the test audience and whether the subnet, public IPv4 and local Tomcat listener are correct.
2. Limit access to trusted administrators to reduce exposure to SSH account and protocol attacks.
3. Customers see refused or timed-out requests until the listener returns.
4. Scale Tomcat across Availability Zones, using shared durable state and a health-checked load balancer.
5. The load balancer distributes requests and routes around failed instances.

## Common failures and fixes

- **Port in use.** In PowerShell, run `Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 8080,8186,8896,8316 }`. Identify the PID with `Get-Process -Id PID` after replacing PID. For Docker use `docker ps --format "table {{.Names}}	{{.Ports}}"`. On macOS use `lsof -nP -iTCP -sTCP:LISTEN`. Change the matching local port in `.env` where permitted.
- **Missing WAR.** Run `./scripts/setup.ps1 -FetchOnly` and `mvn -B -ntp -f app/upstream/pom.xml clean test package`. Expect `app/upstream/target/VehicleRentalManagement.war`. For failed dependency resolution use `mvn -U -e -f app/upstream/pom.xml clean package` and inspect the failing repository or proxy.
- **Engine inactive.** Check `docker context ls` and `docker version`. Wait for the Linux engine. Check permission under the Jenkins agent user separately.
- **Database unhealthy.** Run `docker compose ps` and `docker compose logs --tail=80 web db`. Initialization uses credentials from the first boot of the named volume. Restore the original `.env` or rotate the database account explicitly.
- **No Nagios status.** Verify daemon status and config, then wait for the next active check. Include both Compose files when inspecting monitoring.

## Verify and clean up

**PowerShell** Run `./scripts/setup.ps1` first. Complete WordPress setup and replace NUMBER with your published page ID or supply its actual local path.

```powershell
./scripts/verify.ps1 -WordPressQuery '/?page_id=NUMBER' -WordPressMarker 'Airport pickup and compact car rentals' -RecreateDatabase -Kubernetes
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
| Jenkins Q2 | Console phases, branch or trigger and archived `VehicleRentalManagement.war` with red and green runs. |
| Minikube Q3 | 2 and 4 Ready replicas, endpoints, a new Pod name and HTTP at v2 and restored v1. |
| Nagios Q4 | Verified configuration, active HTTP and DB services, CPU/memory/disk/uptime, CRITICAL and recovery. |
| EC2 Q5 | Public IPv4, matching inbound TCP 8080, local curl and external browser. |
