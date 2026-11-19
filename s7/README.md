# SET-7 — Sports Management System

## Before starting

**Assigned source** [sarasrija/SportSystem](https://github.com/sarasrija/SportSystem), branch `main`.

Install [Git](https://git-scm.com/downloads), [JDK 21](https://adoptium.net/temurin/releases/?version=21), [Maven](https://maven.apache.org/download.cgi), [Jenkins LTS](https://www.jenkins.io/download/), [Docker Desktop](https://www.docker.com/products/docker-desktop/) [Minikube](https://minikube.sigs.k8s.io/docs/start/) and [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/). Use [Windows OpenSSH](https://learn.microsoft.com/windows-server/administration/openssh/openssh_install_firstuse) for EC2.

Start Docker Desktop in **Linux containers** mode.
**Administrator PowerShell, any folder**
```powershell
Get-Service *jenkins*
Start-Service Jenkins
```

If the service name differs, use the **Name** shown above. Wait for Docker Desktop.
**PowerShell, in the folder where you want the Araiza checkout**
```powershell
docker compose version
git clone --branch lab/nine-set-execution --single-branch https://github.com/DevXOmar/Araiza.git
cd Araiza\s7
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Keep this PowerShell open for the local steps.

| Open | URL |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose app | `http://127.0.0.1:8187/` |
| Minikube port-forward | `http://127.0.0.1:8317/` |
| Nagios | `http://127.0.0.1:8897/nagios/` |
| EC2 app | `http://PUBLIC_IP:8080/` |

## Q1 — Jenkins — Scripted Pipeline & Build Triggers

Build the assigned Java project and archive `sportssystem.war`.

**Jenkins GUI** At [localhost:8080](http://localhost:8080/), install **Pipeline, Git, GitHub and Pipeline Stage View** under **Manage Jenkins → Plugins**. Under **Tools**, set **JDK21** and **Maven3** to your JDK and Maven installation folders, one level above `bin`.
**PowerShell in Araiza/s7**
```powershell
Get-Content -Raw .\Jenkinsfile | Set-Clipboard
```

**Jenkins GUI**

1. **New Item → s7-pipeline → Pipeline → OK**. Under **Configure → Pipeline → Pipeline script**, paste the copied [Jenkinsfile](Jenkinsfile). Keep **Groovy Sandbox** checked.
2. Under **Build Triggers**, use **Poll SCM** with `H/5 * * * *`.
3. **Save → Build Now**. Under **Build History**, open **Console Output** and check **Artifacts**.
4. To show a red run, use **Build with Parameters**, set `SOURCE_BRANCH` to `no-such-lab-branch`, build once, then restore `main`.

For a GitHub push demo, set the job script's `SOURCE_URL` default to your fork, switch the trigger to **GitHub hook trigger for GITScm polling**, and run once. In the fork use **Settings → Webhooks → Add webhook**, a reachable Jenkins HTTPS URL ending in `/github-webhook/`, **application/json**, and **Just the push event**.

**Expected** Jenkins archives `sportssystem.war` from a successful run and shows each stage in Console Output.

**Scenario questions**

**1. Your manager asks you to clean the workspace before building—which stage or command in the pipeline script takes care of it?**<br>The Clean workspace stage calls `deleteDir()` before Git checkout.<br><br>
**2. If Maven is not configured globally in Jenkins, which section of the pipeline script will fail first?**<br>The `tool name: 'Maven3', type: 'maven'` step fails when no tool by that name is configured.<br><br>
**3. Instead of running nightly builds, you want this pipeline to trigger only when GitHub changes occur—where will you configure this trigger?**<br>In **Configure → Build Triggers**, enable **GitHub hook trigger for GITScm polling** and turn off periodic polling.<br><br>
**4. If you replace mvn clean with mvn compile, what difference will it make to the project build output?**<br>`compile` compiles source into `target`, while `clean` deletes previous output.<br><br>
**5. What is the difference between polling and webhook triggers in Jenkins?**<br>Poll SCM checks Git on a schedule, while a webhook asks Jenkins to check when a push occurs.

## Q2 — AWS — Cloud Deployment using EC2

Deploy the assigned app to Ubuntu EC2.

**AWS console** [awsacademy.instructure.com](https://awsacademy.instructure.com/) → **Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved x86 instance, about **16 GiB gp3** if allowed, **public IPv4**, and a `.pem` key pair. Inbound rules are **TCP 22 from My IP** and **TCP 8080 from your or the examiner's IP**.
**PowerShell in Araiza/s7**
```powershell
$pem = Read-Host 'Full path to your downloaded .pem file'
$ec2 = Read-Host 'EC2 public IPv4'
ssh -i ($pem.Trim('"')) "ubuntu@$ec2"
```
**Ubuntu EC2 terminal, in the Ubuntu home directory**
```bash
sudo apt-get update
sudo apt-get install -y git
git clone --branch lab/nine-set-execution --single-branch https://github.com/DevXOmar/Araiza.git
cd Araiza/s7
```

[deploy.sh](aws/deploy.sh) fetches the Java source, builds the WAR and starts Tomcat on port 8080.
**Ubuntu EC2 terminal, in Araiza/s7**
```bash
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

After reboot, confirm Tomcat starts again with `systemctl is-enabled araiza-s7-tomcat` from Ubuntu.

**Browser** Replace `PUBLIC_IP` in `http://PUBLIC_IP:8080/` with the EC2 address. If it fails, run `sudo journalctl -u araiza-s7-tomcat -n 60 --no-pager` in the Ubuntu SSH window and check the inbound rule.

**Expected** Your application opens at the public address.

**Scenario questions**

**1. You built a Maven project on EC2, and a .war file generated inside target/. Where will you place the .war file for Tomcat execution, and why?**<br>Put `sportssystem.war` in `/opt/araiza-s7-tomcat/webapps/ROOT.war` so Tomcat serves it at `/`.<br><br>
**2. Your Maven web app is deployed to Tomcat on EC2, but accessing it via browser gives a 404 error. What configuration or path issues will you check?**<br>Check the Tomcat logs and deployment paths, and browse to `/` or `/schedule.jsp` for `ROOT.war`.<br><br>
**3. You have deployed your web app on EC2 successfully, but after restarting your instance, the public IP changed and the app is not opening. What AWS feature helps avoid this issue?**<br>Associate an Elastic IP if AWS Academy permits it.<br><br>
**4. Your Maven application needs external dependencies during build, but EC2 has no internet. What AWS service or change allows the EC2 instance to download dependencies securely?**<br>Use a NAT gateway for a private subnet or a public IP and internet gateway route for a public subnet.<br><br>
**5. What command should you run to ensure a web server service auto-starts on EC2 instance boot?**<br>On Ubuntu run `sudo systemctl enable --now araiza-s7-tomcat` and confirm `systemctl is-enabled araiza-s7-tomcat`.

## Q3 — Kubernetes & Nagios — Minikube Pods & Infrastructure Monitoring

Deploy the Java app with [deployment.yaml](k8s/deployment.yaml) and [service.yaml](k8s/service.yaml), then scale from 2 to 4 replicas.
**PowerShell in Araiza/s7**
```powershell
.\scripts\setup.ps1
minikube start --driver=docker
minikube image load araiza-s7:v1
```
**PowerShell in Araiza/s7**
```powershell
$ns = 'araiza-s7'
kubectl --context minikube apply -f k8s\namespace.yaml
kubectl --context minikube -n $ns apply -f k8s\deployment.yaml -f k8s\service.yaml
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get 'deploy,pods,svc'
```

Leave this port-forward to the NodePort Service running and open [the app](http://127.0.0.1:8317/).
**Second PowerShell, any folder**
```powershell
kubectl --context minikube -n araiza-s7 port-forward svc/araiza-s7 8317:8080
```

Back in the first window, scale and delete one Pod. Compare its name with the names after recovery.
**PowerShell in Araiza/s7**
```powershell
kubectl --context minikube -n $ns scale deployment/$ns --replicas=4
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
$pod = kubectl --context minikube -n $ns get pods -l "app=$ns" -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n $ns delete pod $pod
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get pods
```

For troubleshooting, set `$pod` to the current failing Pod name from `get pods`.

**Expected** The Java app opens and 4 Pods become Ready with a new Pod name after deletion.

### Nagios

Start Nagios with the checks supplied in [lab.cfg](nagios/lab.cfg). This also starts the services used in Q4.
**PowerShell in Araiza/s7**
```powershell
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build --wait --wait-timeout 180
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
(Get-Content .env | Select-String '^NAGIOS_PASSWORD=').Line.Split('=', 2)[1]
```

**Browser** Open [Nagios](http://127.0.0.1:8897/nagios/) as `nagiosadmin` with the password above. Under **Services**, show **Portal HTTP**, **Database TCP**, CPU, memory, disk and uptime. WARNING / CRITICAL are 75% / 90% for CPU and memory, 80% / 95% disk, under 120s / 30s uptime, and 1s / 3s HTTP response time.

Run these lines individually. After each stop wait for CRITICAL (about a minute), then run its start and show recovery in **Alert History**.
**PowerShell in Araiza/s7**
```powershell
docker compose stop db
docker compose start db
docker compose stop web
docker compose start web
```

**Expected** Nagios validates with zero errors and records CRITICAL → OK for the database and HTTP checks.

**Scenario questions**

**1. Your Pod keeps restarting repeatedly (CrashLoopBackOff). What will you do to troubleshoot this issue?**<br>In the first PowerShell, run `kubectl --context minikube -n $ns logs $pod -c web --previous` on the restarting Pod.<br><br>
**2. A Kubernetes pod is stuck in a Pending state. What could be the possible reasons, and how would you troubleshoot it?**<br>Run `kubectl --context minikube -n $ns describe pod $pod` and check the events for resource or scheduling errors.<br><br>
**3. You have a Kubernetes Deployment with multiple replicas, and some pods are failing health checks. How would you identify the root cause and fix it?**<br>Compare each Pod's logs and events with the probe path and port, then fix the failing configuration.<br><br>
**4. You installed Nagios, but the web interface shows "Unable to connect to Nagios process". How do you resolve this?**<br>Run `docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios sv status nagios` from this set.<br><br>
**5. You added a new host in Nagios, but it's not appearing on the web interface. How do you check and fix this?**<br>Check that the host file is mounted in `conf.d`, run the validation above, then restart the Nagios daemon.

## Q4 — Docker Compose — Multi-Container Orchestration

Run [Flask](flask/app.py) with PostgreSQL and Redis using [compose.yaml](compose.yaml) and the [Flask Dockerfile](flask/Dockerfile). Reuse the setup from Q3.
**PowerShell in Araiza/s7**
```powershell
docker compose up -d --build --wait --wait-timeout 180
docker compose ps
curl.exe -fsS http://127.0.0.1:8187/health
curl.exe -fsS -d 'name=Saturday+Final' http://127.0.0.1:8187/fixtures
```

**Browser** Open [http://127.0.0.1:8187/fixtures](http://127.0.0.1:8187/fixtures) twice and watch the Redis visit count increase.

Rebuild only web and compare the DB and Redis IDs, then scale behind the proxy.
**PowerShell in Araiza/s7**
```powershell
docker compose ps -q db redis
docker compose up -d --no-deps --build web
docker compose ps -q db redis
docker compose up -d --no-deps --scale web=2 web
docker compose ps web
```

Recreate PostgreSQL and Redis while keeping their volumes.
**PowerShell in Araiza/s7**
```powershell
docker compose stop db redis
docker compose rm -f db redis
docker compose up -d --wait --wait-timeout 180 db redis
curl.exe -fsS http://127.0.0.1:8187/fixtures
docker compose exec -T redis redis-cli GET fixture-reads
```

**Expected** Both dependencies report OK, two web replicas run, and the fixture and Redis counter survive dependency replacement.

**Scenario questions**

**1. You have two applications—a Node.js backend and a Python script that handles scheduled jobs. Should you run multiple applications in the same Docker container?**<br>Use a backend service and a separate worker service so each can be deployed, stopped and scaled independently.<br><br>
**2. You try to run two containers that both expose port 8080 on the host. What happens, and how can you run both apps?**<br>The second bind fails, so publish a different host port or use a reverse proxy.<br><br>
**3. Your frontend has a new release, but you don’t want to restart the backend or DB containers. How can you update and rebuild only the frontend container?**<br>Run `docker compose up -d --no-deps --build web` and compare the DB and Redis container IDs.<br><br>
**4. Tomcat is listening on port 8080, but you get a "Connection Refused" error in the browser. Why does this happen?**<br>Check `docker ps` and use the published host port to reach Tomcat's container listener.<br><br>
**5. You're not sure which container is using port 3000. How do you check this on your host machine?**<br>Use `docker ps --filter publish=3000`, then `Get-NetTCPConnection -LocalPort 3000` to check a Windows host process.

## Troubleshooting and cleanup

- **Port busy** Run `Get-NetTCPConnection -State Listen -LocalPort 8080,8187,8317,8897 -ErrorAction SilentlyContinue`. For a Compose port conflict, change `WEB_PORT` or `NAGIOS_PORT` in your local `.env` and use that port in the browser.
- **Container unhealthy** Run `docker compose logs --tail=40 web db`. For Jenkins errors, check **Console Output** and the names `JDK21` and `Maven3`.

Stop the port-forward with Ctrl+C. The cleanup command keeps your data volumes.
**PowerShell in Araiza/s7**
```powershell
.\scripts\cleanup.ps1 -Kubernetes
```

End the AWS lab and stop or terminate your EC2 instance when done.

### macOS startup

In Terminal, run `open -a Docker` and `brew services start jenkins-lts` if installed via Homebrew. Clone the same branch, use `cd Araiza/s7`, `bash scripts/setup.sh` and `curl`. The Docker, Minikube and kubectl commands are the same.
