# Set 9 · Apartment Management System

Assigned source [`sarasrija/ApartmentSystem`](https://github.com/sarasrija/ApartmentSystem), default branch `main`. [Source lock](app/source.properties) pins [`805d219`](https://github.com/sarasrija/ApartmentSystem/tree/805d21930a33b6aaec19fe15756066e12dca440b). Bootstrap clones the pinned source to ignored `app/upstream`. The upstream has no license file, so its sources are fetched on demand. It contains JSP pages and a WAR POM with Servlet 4.0.1 and JUnit 4.13.1. There are no upstream test classes or JDBC integration. A clean build produces `target/apartmentsystem.war`. Tomcat 9 provides `javax.servlet` compatibility and serves this file as `ROOT.war` at `/`.

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
Set-Location Araiza/s9
Set-ExecutionPolicy -Scope Process Bypass
```

Wait for `docker info` to report `linux`. Run all local commands in `Araiza/s9`. For a PR preview switch the Araiza checkout to its review branch before entering the directory.

**macOS Terminal**
```bash
open -a Docker
brew services start jenkins-lts
command -v java mvn git docker
/usr/libexec/java_home -V
git clone https://github.com/DevXOmar/Araiza.git
cd Araiza/s9
```

Use `curl` for `curl.exe`. The setup equivalents are `bash scripts/setup.sh`, `bash scripts/setup.sh --env-only` and `bash scripts/setup.sh --fetch-only`. Use [PowerShell for macOS](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-macos) for verification scripts. The Docker and kubectl commands are shared.

## Ports and expected URLs

| Service | Address |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose | `http://127.0.0.1:8189/` and `/lab/` for the database companion |
| Nagios | `http://127.0.0.1:8899/nagios/` |
| Minikube | NodePort `30109` or forwarded `http://127.0.0.1:8319/` |
| EC2 | `http://PUBLIC_IPV4:8090/` |
| Jenkins Tomcat target | `http://127.0.0.1:8199/` |

## Question 1 — Jenkins Pipeline

**Jenkins GUI** Open `http://localhost:8080/`. Under **Manage Jenkins → Plugins → Available plugins**, install Git, GitHub, Pipeline, JUnit and Pipeline Stage View. Under **Manage Jenkins → Tools**, configure Git and name the JDK `JDK21` and Maven `Maven3`. For installed tools, uncheck automatic installation and select the home directory above `bin`. If Git needs an explicit executable, use the path found by `Get-Command git`. Restart Jenkins after system PATH changes.

Maven runs the test lifecycle. The assigned repository has no test classes. The console may show **No tests to run**. Capture that output alongside the WAR.

**PowerShell** Start the named Tomcat deployment target on the agent's Docker engine.

```powershell
docker run -d --name s9-jenkins-tomcat -p 127.0.0.1:8199:8080 tomcat:9.0-jre17-temurin-noble
docker ps --filter name=s9-jenkins-tomcat
```

1. **New Item → s9-pipeline → Pipeline → OK**. Set **Pipeline → Definition → Pipeline script**. Paste [Jenkinsfile](Jenkinsfile), leave **Use Groovy Sandbox** checked, and save.
2. The baseline Git source is `https://github.com/sarasrija/ApartmentSystem.git`. The public HTTPS checkout needs no credential. For automatic webhook builds, edit the `SOURCE_URL` and `SOURCE_BRANCH` default values in the pasted script to point to your writable training fork and exact branch, and run once manually to register Git SCM.

3. **Build Now** archives the WAR, copies it into the target container as `ROOT.war`, restarts Tomcat and checks HTTP. Verify `http://127.0.0.1:8199/` in the browser. For a Maven-only diagnostic run with `DEPLOY_LOCAL=false`.
4. From the Jenkins dashboard choose **+ New View → List View**, name it `Apartment-CI` and select `s9-pipeline`. Inspect **Stage View**, **Build History**, **Console Output** and **Artifacts**.
5. Under **Configure → Build Triggers**, check **GitHub hook trigger for GITScm polling**. Leave Poll SCM off. Install [ngrok](https://ngrok.com/download). In **PowerShell**, set the authtoken privately with `ngrok config edit`, then run `ngrok http 8080` and keep it running.
6. In the GitHub fork choose **Settings → Webhooks → Add webhook**. Use `https://YOUR_NGROK_HOST/github-webhook/`, **application/json**, and **Just the push event**. If you set a shared secret, configure the same secret in the Jenkins GitHub plugin. Keep Jenkins authentication enabled and close ngrok after practice.
7. Push a commit to the configured branch. Check **Recent Deliveries** and `http://127.0.0.1:4040/` for the POST and confirm a new Jenkins run. Update the payload URL whenever the forwarding host changes.

**Troubleshooting** Read the first error in Console Output. On Windows confirm that the Pipeline uses `bat` and check the exact Jenkins tool names. If Jenkins needs Docker, inspect **services.msc → Jenkins → Properties → Log On**. Test `docker version` from the actual agent. Use a trusted interactive agent with Docker Desktop access, or configure the service account's Docker access and restart it. A successful interactive PowerShell test only verifies the logged-in user's access.

## Question 2 — AWS Academy EC2

**AWS console** [AWS Academy](https://awsacademy.instructure.com/) → **Login → Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved instance type (t2.micro if offered, or t3.micro), and at least 12–16 GiB of gp3 if allowed. Create or select a personal `.pem` key pair. Enable public IPv4 in a subnet with an internet gateway route.

Allow inbound TCP 22 from **My IP** (/32) and TCP **8090** from the examiner's IP or permitted audience.  Keep DB ports closed. Use only synthetic data. If a small VM runs out of build memory, use a lab-approved larger instance.

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
cd Araiza/s9
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8090/
```

[deploy.sh](aws/deploy.sh) installs Docker and Git, builds the pinned WAR and Tomcat image using the [multi-stage Dockerfile](Dockerfile), and maps EC2 port 8090 to container port 8080. Docker starts at boot and the container has an `unless-stopped` policy.

**Ubuntu EC2 terminal**
```bash
sudo systemctl status docker --no-pager
sudo docker ps -a --filter name=araiza-s9-ec2
sudo docker port araiza-s9-ec2
sudo docker logs --tail=80 araiza-s9-ec2
sudo ss -lnt
```

**Laptop browser** Open `http://PUBLIC_IPV4:8090/`.  If local curl works and external access times out, check public IPv4, the app port in the attached security group, subnet route and `sudo ufw status` in Ubuntu. If local curl fails, check listeners and server logs. For 404, check the context and whether `ROOT.war` deployed.

## Question 3 — Minikube and Nagios

Apply the provided [Deployment](k8s/deployment.yaml), [Service](k8s/service.yaml) and [namespace](k8s/namespace.yaml). This uses the actual Java image with startup, readiness and liveness probes.

**PowerShell**
```powershell
./scripts/setup.ps1
minikube start --driver=docker
minikube status
minikube image load araiza-s9:v1
kubectl --context minikube apply -f k8s/namespace.yaml
kubectl --context minikube -n araiza-s9 apply -f k8s/deployment.yaml -f k8s/service.yaml
kubectl --context minikube -n araiza-s9 rollout status deployment/araiza-s9 --timeout=240s
kubectl --context minikube -n araiza-s9 get 'deployment,pods,svc' -o wide
kubectl --context minikube -n araiza-s9 get endpointslices -l kubernetes.io/service-name=araiza-s9
minikube service araiza-s9 -n araiza-s9 --url
```

Expect 4 Ready Pods and endpoints. Keep the Minikube service tunnel open if the Docker driver starts one. Use its listed URL, or use port-forward in another terminal.

```powershell
kubectl --context minikube -n araiza-s9 port-forward service/araiza-s9 8319:8080
```

```powershell
curl.exe -fsS http://127.0.0.1:8319/
curl.exe -fsS http://127.0.0.1:8319/complaints.jsp
```

**PowerShell** Scale manually to 6, inspect Pod names, delete one and verify that the replacement has a different name. Use a second PowerShell window. If the deleted Pod was selected by port-forward, rerun the forward command.

```powershell
kubectl --context minikube -n araiza-s9 scale deployment/araiza-s9 --replicas=6
kubectl --context minikube -n araiza-s9 rollout status deployment/araiza-s9 --timeout=240s
kubectl --context minikube -n araiza-s9 get pods -o wide
$pod = kubectl --context minikube -n araiza-s9 get pods -l app=araiza-s9 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s9 delete pod $pod
kubectl --context minikube -n araiza-s9 rollout status deployment/araiza-s9 --timeout=240s
kubectl --context minikube -n araiza-s9 get pods -o wide
```

**PowerShell** Roll to the second image, then roll back. The build adds a visible revision label to the same upstream application. Reopen the forward after each rollout and check `http://127.0.0.1:8319/revision/index.txt` for `v2` and then `v1`.

```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s9:v2 .
minikube image load araiza-s9:v2
kubectl --context minikube -n araiza-s9 set image deployment/araiza-s9 web=araiza-s9:v2
kubectl --context minikube -n araiza-s9 rollout status deployment/araiza-s9 --timeout=240s
kubectl --context minikube -n araiza-s9 rollout history deployment/araiza-s9
```

```powershell
kubectl --context minikube -n araiza-s9 rollout undo deployment/araiza-s9
kubectl --context minikube -n araiza-s9 rollout status deployment/araiza-s9 --timeout=240s
```

**Troubleshooting** Replace a failing image with the correct loaded tag. Check startup logs and last termination reason for a crashing Pod. In a Pending Pod's events look for scheduling errors and resource shortages.

```powershell
$pod = kubectl --context minikube -n araiza-s9 get pods -l app=araiza-s9 -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n araiza-s9 describe pod $pod
kubectl --context minikube -n araiza-s9 logs $pod -c web --tail=60
kubectl --context minikube -n araiza-s9 logs $pod -c web --previous
kubectl --context minikube -n araiza-s9 get events --sort-by=.lastTimestamp
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

**Browser** Open `http://127.0.0.1:8899/nagios/`. Use `nagiosadmin` and the password in your local `.env`. Check **Hosts**, **Services** and **Alert History**. CPU and memory use 75% WARNING and 90% CRITICAL. Disk uses 80%/95% used. Uptime warns below 120s and is critical below 30s. HTTP warns at 1s, becomes critical at 3s or on an error status. The dashboard and alert history record state changes. Outbound email is disabled.

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

[compose.yaml](compose.yaml) runs the assigned WAR at `/` and the separately labeled companion WAR at `/lab/` in the same Tomcat service. The maintenance companion stores synthetic request references and unit numbers. The `s9` folder is the Compose working directory. Compose v2 uses the current Compose Specification with the features requested under version 3.9. The companion uses a restricted SQL account and prepared statements, checks a real query, and returns 503 when the database is unreachable. The application and DB share `s9-data-net`, use `db` as the hostname and retain data in `s9-db-data`. The database has no host port.

**PowerShell**
```powershell
./scripts/setup.ps1
docker compose config --quiet
docker compose up -d --build --wait --wait-timeout 180
docker compose ps
curl.exe -fsS http://127.0.0.1:8189/lab/health
```

**Browser** Open `http://127.0.0.1:8189/` for the original Java home page and `http://127.0.0.1:8189/lab/` for the database-backed form. Use a new synthetic reference if `Lab-01` is already saved.

```powershell
curl.exe -fsS -d 'reference=Lab-01' --data-urlencode 'unit=B-12' http://127.0.0.1:8189/lab/records
```

**PowerShell** Read the record, simulate loss of the DB, then recreate its container.

```powershell
curl.exe -fsS http://127.0.0.1:8189/lab/records
docker compose kill db
curl.exe -i --max-time 8 http://127.0.0.1:8189/lab/health
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
curl.exe -fsS http://127.0.0.1:8189/lab/records
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
curl.exe -fsS http://127.0.0.1:8189/lab/records
```

## Scenario answers

### Question 1

1. Confirm the ngrok forwarding line still points at port 8080. Check `127.0.0.1:4040` for the POST and compare the HTTPS address and path with GitHub.
2. Read the Jenkins Console Output for Maven's compiler error, file, line and column.
3. No new WAR is packaged on a normal test failure because Maven stops at the test phase.
4. GitHub needs a reachable webhook receiver. The ngrok HTTPS URL forwards to the authenticated local Jenkins instance.
5. CI builds and verifies commits. Continuous Deployment automatically releases changes that pass the required gates.

### Question 2

1. The wrong address may time out or refuse the connection. Browse `http://PUBLIC_IPV4:8090/` and allow inbound TCP 8090 from the test audience.
2. Opening TCP 22 to everyone exposes the administrative listener to scanning and login attempts.
3. On Ubuntu run `sudo apt-get update` followed by `sudo apt-get install -y docker.io git` and `sudo systemctl enable --now docker`.
4. On Ubuntu run `sudo docker ps -a --filter name=araiza-s9-ec2` and `sudo docker logs --tail=80 araiza-s9-ec2`.
5. Use multiple instances across zones with an ALB, health checks, backups and an independent data store.

### Question 3

1. The kubelet restarts a failed container. If the Pod is lost, the ReplicaSet creates a replacement and other Ready replicas serve.
2. A Pod IP identifies one temporary replica. The Service IP is stable and routes to the currently Ready replicas.
3. Run `kubectl --context minikube -n araiza-s9 get pods -o wide`.
4. Run `kubectl --context minikube -n araiza-s9 port-forward service/araiza-s9 8319:8080` and open `http://127.0.0.1:8319/`.
5. Nagios requests the portal's HTTP endpoint and flags error status or excessive latency separately from host liveness.

### Question 4

1. `depends_on` orders startup. In this stack `service_healthy` waits for an authenticated SQL query before Tomcat starts.
2. The named volume keeps database files through `down`. Without a reusable volume, the new DB can initialize empty.
3. The running image still contains the old build context. Use `docker compose up -d --build` to rebuild and apply changes.
4. Docker DNS resolves `db` on the shared data network, even when its IP changes.
5. Reattach `s9-db-data` with its original credentials. If the volume is lost, restore a saved PostgreSQL dump.

## Common failures and fixes

- **Port in use.** In PowerShell, run `Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 8080,8189,8899,8319,8199 }`. Identify the PID with `Get-Process -Id PID` after replacing PID. For Docker use `docker ps --format "table {{.Names}}	{{.Ports}}"`. On macOS use `lsof -nP -iTCP -sTCP:LISTEN`. Change the matching local port in `.env` where permitted.
- **Missing WAR.** Run `./scripts/setup.ps1 -FetchOnly` and `mvn -B -ntp -f app/upstream/pom.xml clean test package`. Expect `app/upstream/target/apartmentsystem.war`. For failed dependency resolution use `mvn -U -e -f app/upstream/pom.xml clean package` and inspect the failing repository or proxy.
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
docker rm -f s9-jenkins-tomcat
```

On macOS use `pwsh -File scripts/cleanup.ps1 -Kubernetes`. Cleanup leaves the database volumes, WordPress files, Redis data and `.env` wherever present. Stop any webhook tunnel and disable the practice webhook. In AWS, stop for later use or terminate the instance when evidence is saved. Release lab-only Elastic IPs and retained disks as allowed, then end the Academy lab.

## Evidence checklist

| Exercise | Capture |
| --- | --- |
| Containers Q4 | Working page and health, saved record before and after DB replacement. |
| Jenkins Q1 | Console phases, branch or trigger and archived `apartmentsystem.war`, Stage View, Build History and Tomcat HTTP. |
| Minikube Q3 | 4 and 6 Ready replicas, endpoints, a new Pod name and HTTP at v2 and restored v1. |
| Nagios Q3 | Verified configuration, active HTTP and DB services, CPU/memory/disk/uptime, CRITICAL and recovery. |
| EC2 Q2 | Public IPv4, matching inbound TCP 8090, local curl and external browser. |
