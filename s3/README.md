# SET-3 — Online Recruitment System

## Before starting

**Assigned source** [ssvkotamraju/ORS](https://github.com/ssvkotamraju/ORS), branch `main`.

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
cd Araiza\s3
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Keep this PowerShell open for the local steps.

| Open | URL |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose app | `http://127.0.0.1:8183/` |
| Minikube port-forward | `http://127.0.0.1:8313/` |
| Nagios | `http://127.0.0.1:8893/nagios/` |
| EC2 app | `http://PUBLIC_IP:8080/` |

## Q1 — Docker — Multi-Container Application

Run the assigned Java app with MySQL and use the lab companion to save applications and résumés. [compose.yaml](compose.yaml) sets up `ors-net` and `s3-db-data`.
**PowerShell in Araiza/s3**
```powershell
.\scripts\setup.ps1
docker compose up -d --build --wait --wait-timeout 180
docker compose ps
```

**Browser** Open [http://127.0.0.1:8183/](http://127.0.0.1:8183/) for the Java app and [http://127.0.0.1:8183/lab/](http://127.0.0.1:8183/lab/) for the database form. Use sample data.
**PowerShell in Araiza/s3**
```powershell
$ref = 'Exam-' + (Get-Date -Format yyyyMMddHHmmss)
$resume = Join-Path $env:TEMP 'araiza-exam-resume.txt'
Set-Content -Path $resume -Value 'Sample resume' -Encoding Ascii
curl.exe -fsS -F "reference=$ref" -F 'position=Analyst' -F "resume=@$resume" http://127.0.0.1:8183/lab/records
```

Replace MySQL, then read the saved record and résumé again.
**PowerShell in Araiza/s3**
```powershell
docker compose stop db
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
curl.exe -fsS http://127.0.0.1:8183/lab/records
curl.exe -fsS "http://127.0.0.1:8183/lab/resume?reference=$ref"
```
**PowerShell in Araiza/s3**
```powershell
docker compose up -d --no-deps --scale web=2 web
docker compose ps web proxy
```

**Expected** Your `Exam-...` record and résumé survive DB replacement, and the proxy serves two web containers.

**Scenario questions**

**1. What happens to active candidate application submissions if the MySQL container crashes mid-transaction?**<br>Uncommitted submissions roll back, so verify the original reference before resubmitting.<br><br>
**2. How can uploaded resume files and applicant histories be recovered after container deletion?**<br>Reattach `s3-db-data` and `s3-resumes`, or restore matching SQL and upload backups.<br><br>
**3. Why is a custom Docker network required for the recruitment system containers?**<br>`ors-net` supplies stable service DNS and prevents unrelated containers from reaching the database by default.<br><br>
**4. How would you secure database credentials to prevent unauthorized database modifications?**<br>Use a restricted MySQL account, private credentials and an unpublished database port.<br><br>
**5. How would you deploy multiple instances of the ORS application using Docker Compose?**<br>Run `docker compose up -d --no-deps --scale web=2 web` to share the DB and resume volume behind Nginx.

## Q2 — Jenkins — Java Application Build and Continuous Integration

Build the assigned Java project and archive `ORS.war`.

**Jenkins GUI** At [localhost:8080](http://localhost:8080/), install **Pipeline, Git, GitHub, JUnit and Pipeline Stage View** under **Manage Jenkins → Plugins**. Under **Tools**, set **JDK21** and **Maven3** to your JDK and Maven installation folders, one level above `bin`.
**PowerShell in Araiza/s3**
```powershell
$job = Get-Content -Raw .\Jenkinsfile
$job = $job.Replace("'LAB_BRANCH', defaultValue: 'main'", "'LAB_BRANCH', defaultValue: 'lab/nine-set-execution'")
$job = $job.Replace("'SOURCE_BRANCH', defaultValue: 'release'", "'SOURCE_BRANCH', defaultValue: 'main'")
$job | Set-Clipboard
```

**Jenkins GUI**

1. **New Item → s3-pipeline → Pipeline → OK**. Under **Configure → Pipeline → Pipeline script**, paste the copied [Jenkinsfile](Jenkinsfile). Keep **Groovy Sandbox** checked.
2. Under **Build Triggers**, use **Poll SCM** with `H/5 * * * *`.
3. **Save → Build Now**. Under **Build History**, open **Console Output** and check **Artifacts**.
4. **Build with Parameters → FAIL_TEST → Build** makes a red JUnit run. Clear `FAIL_TEST` for the next run. The copied script already sets `LAB_BRANCH` to `lab/nine-set-execution`.

For the release trigger demo, create `release` on your ORS fork, then set the job script's `SOURCE_URL` and `SOURCE_BRANCH` defaults to your fork and `release`. Check the result in **Build History**. For email specifically, configure Jenkins **Mailer → E-mail Notification** and set `NOTIFY_TO` to your lab inbox.

For a GitHub push demo, set the job script's `SOURCE_URL` default to your fork, switch the trigger to **GitHub hook trigger for GITScm polling**, and run once. In the fork use **Settings → Webhooks → Add webhook**, a reachable Jenkins HTTPS URL ending in `/github-webhook/`, **application/json**, and **Just the push event**.

**Expected** The green run archives `ORS.war` and the red run stops at the intended failure.

**Scenario questions**

**1. How does Jenkins identify compilation errors during the Maven build phase?**<br>Maven's nonzero exit fails Jenkins, and Console Output shows the file and compiler error.<br><br>
**2. What happens to the build status if compilation succeeds but candidate profile unit tests fail?**<br>A failing test stops packaging, and Jenkins keeps the failure in the JUnit result.<br><br>
**3. Why is Maven used instead of manually managing JAR files for recruitment system dependencies?**<br>Maven resolves the pinned dependencies and their transitives using the POM and caches the artifacts.<br><br>
**4. How can Jenkins be configured to build only the release branch?**<br>Create `release` in your fork and set the job's source URL and exact branch to that fork and `release`.<br><br>
**5. What is the core difference between Continuous Integration and Continuous Deployment?**<br>CI verifies changes, while Continuous Deployment releases changes that pass.

## Q3 — Kubernetes — Container Deployment and Auto Scaling

Deploy the Java app with [deployment.yaml](k8s/deployment.yaml) and [service.yaml](k8s/service.yaml), then scale from 2 to 5 replicas.
**PowerShell in Araiza/s3**
```powershell
.\scripts\setup.ps1
minikube start --driver=docker
minikube image load araiza-s3:v1
```
**PowerShell in Araiza/s3**
```powershell
$ns = 'araiza-s3'
kubectl --context minikube apply -f k8s\namespace.yaml
kubectl --context minikube -n $ns apply -f k8s\deployment.yaml -f k8s\service.yaml
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get 'deploy,pods,svc'
```

Leave this port-forward to the NodePort Service running and open [the app](http://127.0.0.1:8313/).
**Second PowerShell, any folder**
```powershell
kubectl --context minikube -n araiza-s3 port-forward svc/araiza-s3 8313:8080
```

Back in the first window, scale and delete one Pod. Compare its name with the names after recovery.
**PowerShell in Araiza/s3**
```powershell
kubectl --context minikube -n $ns scale deployment/$ns --replicas=5
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
$pod = kubectl --context minikube -n $ns get pods -l "app=$ns" -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n $ns delete pod $pod
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get pods
```

Update to v2, then undo the update. Relaunch the port-forward if its Pod was replaced.
**PowerShell in Araiza/s3**
```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s3:v2 .
minikube image load araiza-s3:v2
kubectl --context minikube -n $ns set image deployment/$ns web=araiza-s3:v2
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get deployment $ns -o wide
kubectl --context minikube -n $ns rollout undo deployment/$ns
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get deployment $ns -o wide
```

**Expected** The Java app opens and 5 Pods become Ready with a new Pod name after deletion.

**Scenario questions**

**1. What happens when a pod hosting the candidate search engine crashes?**<br>The Service routes to Ready Pods while Kubernetes restarts or replaces the failed replica.<br><br>
**2. How does Kubernetes maintain the desired replica count automatically?**<br>The ReplicaSet reconciles its desired count to actual running Pods.<br><br>
**3. What is the difference between manual scaling and Autoscaling (HPA)?**<br>Manual scaling sets a fixed count; HPA changes the count using metrics.<br><br>
**4. Why is a Kubernetes Service required when pods are rescheduled with new IP addresses?**<br>A Service name and IP persist while EndpointSlices update when Pods move.<br><br>
**5. How can you recover from a failed ORS deployment update using kubectl rollout undo?**<br>Run `kubectl --context minikube -n araiza-s3 rollout undo deployment/araiza-s3` and verify the previous revision's responses.

## Q4 — Nagios — Infrastructure and Application Monitoring

Start Nagios with the checks supplied in [lab.cfg](nagios/lab.cfg). Keep the Compose app from Q1 available.
**PowerShell in Araiza/s3**
```powershell
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build --wait --wait-timeout 180
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
(Get-Content .env | Select-String '^NAGIOS_PASSWORD=').Line.Split('=', 2)[1]
```

**Browser** Open [Nagios](http://127.0.0.1:8893/nagios/) as `nagiosadmin` with the password above. Under **Services**, show **Portal HTTP**, **Database TCP**, CPU, memory, disk and uptime. WARNING / CRITICAL are 75% / 90% for CPU and memory, 80% / 95% disk, under 120s / 30s uptime, and 1s / 3s HTTP response time.

Run these lines individually. After each stop wait for CRITICAL (about a minute), then run its start and show recovery in **Alert History**.
**PowerShell in Araiza/s3**
```powershell
docker compose stop db
docker compose start db
docker compose stop web
docker compose start web
```

**Expected** Nagios validates with zero errors and records CRITICAL → OK for the database and HTTP checks.

**Scenario questions**

**1. How does Nagios identify high CPU utilization on the server hosting the resume parser?**<br>Nagios checks sampled CPU use against 75% WARNING and 90% CRITICAL.<br><br>
**2. What is the difference between WARNING and CRITICAL states in Nagios?**<br>WARNING signals degradation, while CRITICAL signals severe use or a failed availability check.<br><br>
**3. How can Nagios identify an application-level failure when the host server is running?**<br>Nagios checks the HTTP status and the companion’s SQL health endpoint even when the host responds.<br><br>
**4. What happens to monitoring operations if the Nagios server container fails?**<br>The application can stay up while Nagios checks and alerts stop.<br><br>
**5. How would you determine whether portal downtime is caused by Tomcat, MySQL, or network connectivity?**<br>Compare Tomcat HTTP, SQL health and the MySQL port, then check DNS and the proxy listener.

## Q5 — AWS — Cloud Deployment using EC2

Deploy the assigned app to Ubuntu EC2.

**AWS console** [awsacademy.instructure.com](https://awsacademy.instructure.com/) → **Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved x86 instance, about **16 GiB gp3** if allowed, **public IPv4**, and a `.pem` key pair. Inbound rules are **TCP 22 from My IP** and **TCP 8080 from your or the examiner's IP**.
**PowerShell in Araiza/s3**
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
cd Araiza/s3
```

[deploy.sh](aws/deploy.sh) fetches the Java source, builds the WAR and starts Tomcat on port 8080.
**Ubuntu EC2 terminal, in Araiza/s3**
```bash
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

**Browser** Replace `PUBLIC_IP` in `http://PUBLIC_IP:8080/` with the EC2 address. If it fails, run `sudo journalctl -u araiza-s3-tomcat -n 60 --no-pager` in the Ubuntu SSH window and check the inbound rule.

**Expected** Your application opens at the public address.

**Scenario questions**

**1. What misconfigurations in AWS Security Groups could prevent candidates from accessing the recruitment portal?**<br>Check whether TCP 8080 is admitted from the test audience, then verify public IPv4, subnet route and the Tomcat listener.<br><br>
**2. Why should SSH access (Port 22) be restricted to administrative IP addresses?**<br>Limit TCP 22 to administrators to reduce exposure to unsolicited logins.<br><br>
**3. What happens to active recruiter sessions if the Tomcat service stops while EC2 is running?**<br>Requests fail and in-memory sessions can be lost while committed database records persist.<br><br>
**4. How can application availability be improved beyond a single EC2 instance?**<br>Run more than one application instance, use health checks and shared durable state, and keep backups.<br><br>
**5. Why would an Application Load Balancer and multiple EC2 instances be better than a single EC2 instance for peak hiring season traffic?**<br>An ALB spreads peak hiring traffic and removes failed targets while other instances serve.

## Troubleshooting and cleanup

- **Port busy** Run `Get-NetTCPConnection -State Listen -LocalPort 8080,8183,8313,8893 -ErrorAction SilentlyContinue`. For a Compose port conflict, change `WEB_PORT` or `NAGIOS_PORT` in your local `.env` and use that port in the browser.
- **Container unhealthy** Run `docker compose logs --tail=40 web db`. For Jenkins errors, check **Console Output** and the names `JDK21` and `Maven3`.

Stop the port-forward with Ctrl+C. The cleanup command keeps your data volumes.
**PowerShell in Araiza/s3**
```powershell
.\scripts\cleanup.ps1 -Kubernetes
```

End the AWS lab and stop or terminate your EC2 instance when done.

### macOS startup

In Terminal, run `open -a Docker` and `brew services start jenkins-lts` if installed via Homebrew. Clone the same branch, use `cd Araiza/s3`, `bash scripts/setup.sh` and `curl`. The Docker, Minikube and kubectl commands are the same.
