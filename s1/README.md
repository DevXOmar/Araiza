# SET-1 — E-Ticketing

## Before starting

**Assigned source** [ssvkotamraju/E-ticketing](https://github.com/ssvkotamraju/E-ticketing), branch `main`.

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
cd Araiza\s1
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Keep this PowerShell open for the local steps.

| Open | URL |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose app | `http://127.0.0.1:80/` |
| Minikube port-forward | `http://127.0.0.1:8311/` |
| Nagios | `http://127.0.0.1:8891/nagios/` |
| EC2 app | `http://PUBLIC_IP/` |

## Q1 — Docker — Multi-Container Application

Run the ticket booking portal with WordPress and MySQL. [compose.yaml](compose.yaml) sets up `eticket-net`, matching credentials and `eticket-db-data`.
**PowerShell in Araiza/s1**
```powershell
.\scripts\setup.ps1 -EnvOnly
docker compose pull
docker compose up -d --wait --wait-timeout 180
docker compose ps
docker compose logs --tail=10 web db
```

**Browser** Open [http://127.0.0.1:80/wp-admin/install.php](http://127.0.0.1:80/wp-admin/install.php). Install WordPress with site title **E-Ticketing**, choose an admin username, password and email, and sign in. In **Pages → Add New**, create **Concert bookings**. Add a **Shortcode** block containing `[lab_ticket_booking]` and publish. While signed in, reserve seat `A7` and try it again to show **Seat already reserved**.

After setup, scale behind the existing [Nginx proxy](proxy.conf), which keeps host port 80.
**PowerShell in Araiza/s1**
```powershell
docker compose up -d --no-deps --scale web=2 web
docker compose ps web proxy
```

Run the first line and refresh to see the outage. Run the last two lines and refresh again.
**PowerShell in Araiza/s1**
```powershell
docker compose kill db
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
```

**Expected** Compose shows the renewed DB as healthy, and seat A7 remains saved under **Saved seats**.

**Scenario questions**

**1. What happens to active user cart transactions if the MySQL container crashes while thousands are booking tickets?**<br>Uncommitted bookings roll back, so check whether the seat was saved before retrying.<br><br>
**2. How can ticket booking history be recovered after complete container deletion?**<br>Recreate MySQL with `eticket-db-data` and the original credentials, or restore a backup if the volume was lost.<br><br>
**3. Why is a custom Docker network required instead of the default bridge?**<br>The user-defined network provides DNS for `db` and isolates lab services from unrelated containers.<br><br>
**4. How would you protect sensitive database root passwords from unauthorized access?**<br>Keep database passwords in your private `.env` and give WordPress only the restricted application account.<br><br>
**5. How would you deploy multiple instances of the E-Ticketing frontend using Docker Compose to balance user load?**<br>After WordPress setup, run `docker compose up -d --no-deps --scale web=2 web` behind the existing proxy on port 80.

## Q2 — Jenkins — Java Application Build and Continuous Integration

Build the assigned Java project and archive `LibraryRegistration.war`.

**Jenkins GUI** At [localhost:8080](http://localhost:8080/), install **Pipeline, Git, GitHub, JUnit and Pipeline Stage View** under **Manage Jenkins → Plugins**. Under **Tools**, set **JDK21** and **Maven3** to your JDK and Maven installation folders, one level above `bin`.
**PowerShell in Araiza/s1**
```powershell
$job = Get-Content -Raw .\Jenkinsfile
$job = $job.Replace("'LAB_BRANCH', defaultValue: 'main'", "'LAB_BRANCH', defaultValue: 'lab/nine-set-execution'")
$job | Set-Clipboard
```

**Jenkins GUI**

1. **New Item → s1-pipeline → Pipeline → OK**. Under **Configure → Pipeline → Pipeline script**, paste the copied [Jenkinsfile](Jenkinsfile). Keep **Groovy Sandbox** checked.
2. Under **Build Triggers**, use **Poll SCM** with `H/5 * * * *`.
3. **Save → Build Now**. Under **Build History**, open **Console Output** and check **Artifacts**.
4. **Build with Parameters → FAIL_TEST → Build** makes a red JUnit run. Clear `FAIL_TEST` for the next run. The copied script already sets `LAB_BRANCH` to `lab/nine-set-execution`.

For a GitHub push demo, set the job script's `SOURCE_URL` default to your fork, switch the trigger to **GitHub hook trigger for GITScm polling**, and run once. In the fork use **Settings → Webhooks → Add webhook**, a reachable Jenkins HTTPS URL ending in `/github-webhook/`, **application/json**, and **Just the push event**.

**Expected** The green run archives `LibraryRegistration.war` and the red run stops at the intended failure.

**Scenario questions**

**1. How does Jenkins identify compilation errors in the ticketing source code?**<br>Console Output shows Maven's compiler error with the file and line number.<br><br>
**2. What happens to the pipeline if compilation succeeds but seat-availability unit tests fail?**<br>Jenkins marks the run failed, skips packaging and leaves the JUnit result for review.<br><br>
**3. Why is Maven preferred over manual JAR downloading for third-party libraries?**<br>Maven uses the POM to download the same pinned libraries and related dependencies on each build.<br><br>
**4. How can Jenkins be configured to build only when changes are pushed to the production branch?**<br>Set the job's source URL to a writable fork and its exact branch to `production`.<br><br>
**5. What is the operational difference between Continuous Integration (CI) and Continuous Deployment (CD)?**<br>CI builds and tests changes, while Continuous Deployment automatically releases changes that pass.

## Q3 — Kubernetes — Container Deployment and Auto Scaling

Deploy the Java app with [deployment.yaml](k8s/deployment.yaml) and [service.yaml](k8s/service.yaml), then scale from 2 to 5 replicas.
**PowerShell in Araiza/s1**
```powershell
.\scripts\setup.ps1
minikube start --driver=docker
minikube image load araiza-s1:v1
```
**PowerShell in Araiza/s1**
```powershell
$ns = 'araiza-s1'
kubectl --context minikube apply -f k8s\namespace.yaml
kubectl --context minikube -n $ns apply -f k8s\deployment.yaml -f k8s\service.yaml
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get 'deploy,pods,svc'
```

Leave this port-forward to the NodePort Service running and open [the app](http://127.0.0.1:8311/).
**Second PowerShell, any folder**
```powershell
kubectl --context minikube -n araiza-s1 port-forward svc/araiza-s1 8311:8080
```

Back in the first window, scale and delete one Pod. Compare its name with the names after recovery.
**PowerShell in Araiza/s1**
```powershell
kubectl --context minikube -n $ns scale deployment/$ns --replicas=5
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
$pod = kubectl --context minikube -n $ns get pods -l "app=$ns" -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n $ns delete pod $pod
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get pods
```

Update to v2, then undo the update. Relaunch the port-forward if its Pod was replaced.
**PowerShell in Araiza/s1**
```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s1:v2 .
minikube image load araiza-s1:v2
kubectl --context minikube -n $ns set image deployment/$ns web=araiza-s1:v2
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get deployment $ns -o wide
kubectl --context minikube -n $ns rollout undo deployment/$ns
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get deployment $ns -o wide
```

**Expected** The Java app opens and 5 Pods become Ready with a new Pod name after deletion.

**Scenario questions**

**1. What happens in the cluster when a pod handling ticket checkouts crashes unexpectedly?**<br>New requests go to other Ready Pods while Kubernetes restarts the container or replaces the Pod.<br><br>
**2. How does the Kubernetes control plane maintain the desired replica count?**<br>The Deployment controller manages ReplicaSets, which reconcile actual replicas to the desired count.<br><br>
**3. What is the operational difference between manual scaling and Autoscaling?**<br>`kubectl scale` sets a fixed count, while HPA changes it using metrics.<br><br>
**4. Why is a Kubernetes Service required when pod internal IP addresses change dynamically?**<br>The Service keeps a stable address and routes to Ready Pods as their IPs change.<br><br>
**5. How can you recover from a failed application update using kubectl rollout undo?**<br>Run `kubectl --context minikube -n araiza-s1 rollout undo deployment/araiza-s1`, wait for rollout status, and confirm `v1` through the Service.

## Q4 — Nagios — Infrastructure and Application Monitoring

Start Nagios with the checks supplied in [lab.cfg](nagios/lab.cfg). Keep the Compose app from Q1 available.
**PowerShell in Araiza/s1**
```powershell
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build --wait --wait-timeout 180
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
(Get-Content .env | Select-String '^NAGIOS_PASSWORD=').Line.Split('=', 2)[1]
```

**Browser** Open [Nagios](http://127.0.0.1:8891/nagios/) as `nagiosadmin` with the password above. Under **Services**, show **Portal HTTP**, **Database TCP**, CPU, memory, disk and uptime. WARNING / CRITICAL are 75% / 90% for CPU and memory, 80% / 95% disk, under 120s / 30s uptime, and 1s / 3s HTTP response time.

Run these lines individually. After each stop wait for CRITICAL (about a minute), then run its start and show recovery in **Alert History**.
**PowerShell in Araiza/s1**
```powershell
docker compose stop db
docker compose start db
docker compose stop web
docker compose start web
```

**Expected** Nagios validates with zero errors and records CRITICAL → OK for the database and HTTP checks.

**Scenario questions**

**1. How does Nagios identify high CPU utilization during a traffic surge?**<br>Nagios checks sampled CPU use against 75% WARNING and 90% CRITICAL.<br><br>
**2. What is the operational difference between a WARNING state and a CRITICAL state?**<br>WARNING signals early degradation, while CRITICAL signals severe usage or a failed service check.<br><br>
**3. How can Nagios detect an HTTP 500 server error even when the Linux server itself is running?**<br>The active HTTP check inspects the status code and marks HTTP 500 CRITICAL even if the host is up.<br><br>
**4. What happens to system monitoring if the Nagios monitoring server container fails?**<br>Active checks and alerts stop until Nagios returns, so an independent monitor should watch the Nagios endpoint.<br><br>
**5. How would you determine if downtime is caused by the Tomcat server, MySQL, or network routing?**<br>Compare Tomcat HTTP and MySQL TCP, then check Compose logs and `getent hosts db` for routing or DNS problems.

## Q5 — AWS — Cloud Deployment using EC2

Deploy the assigned app to Ubuntu EC2.

**Docker Hub** Create a public repo named `araiza-s1` in your account and have a Docker Hub access token ready.
**PowerShell in Araiza/s1**
```powershell
.\scripts\setup.ps1 -FetchOnly
$hub = Read-Host 'Docker Hub username'
docker login --username $hub
docker buildx build --platform linux/amd64 --target app -t "${hub}/araiza-s1:v1" --push .
docker logout
```

**AWS console** [awsacademy.instructure.com](https://awsacademy.instructure.com/) → **Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved x86 instance, about **16 GiB gp3** if allowed, **public IPv4**, and a `.pem` key pair. Inbound rules are **TCP 22 from My IP** and **TCP 80 from your or the examiner's IP**.
**PowerShell in Araiza/s1**
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
cd Araiza/s1
```

[deploy.sh](aws/deploy.sh) builds the assigned WAR and runs the Docker Hub image on port 80.
**Ubuntu EC2 terminal, in Araiza/s1**
```bash
read -rp 'Docker Hub username: ' hub
bash aws/deploy.sh "$hub/araiza-s1:v1"
curl -fsS http://127.0.0.1/
```

**Browser** Replace `PUBLIC_IP` in `http://PUBLIC_IP/` with the EC2 address. If it fails, run `sudo docker logs --tail=60 araiza-s1-ec2` in the Ubuntu SSH window and check the inbound rule.

**Expected** Your application opens at the public address.

**Scenario questions**

**1. What AWS Security Group misconfigurations could make the ticketing application inaccessible in a browser?**<br>Confirm the security group allows TCP 80 from your IP and EC2 maps 80 to Tomcat's 8080.<br><br>
**2. Why should SSH access (Port 22) be restricted to trusted IP addresses?**<br>Limit port 22 to trusted addresses to reduce exposure to scanning and login attempts.<br><br>
**3. What happens to active customer sessions if the Tomcat service stops on the EC2 instance?**<br>In-flight requests fail and in-memory sessions may be lost until Tomcat returns.<br><br>
**4. How can application availability be improved beyond a single EC2 instance?**<br>Run independent instances in different Availability Zones behind health checks and use durable shared data, backups, and a recovery plan.<br><br>
**5. Why would an Application Load Balancer and multiple EC2 instances be superior for ticket sales compared to a single instance?**<br>An ALB distributes ticket traffic across healthy instances, routes around unhealthy targets and supports capacity growth during a sale.

## Troubleshooting and cleanup

- **Port busy** Run `Get-NetTCPConnection -State Listen -LocalPort 8080,80,8311,8891 -ErrorAction SilentlyContinue`. For a Compose port conflict, change `WEB_PORT` or `NAGIOS_PORT` in your local `.env` and use that port in the browser.
- **Container unhealthy** Run `docker compose logs --tail=40 web db`. For Jenkins errors, check **Console Output** and the names `JDK21` and `Maven3`.

Stop the port-forward with Ctrl+C. The cleanup command keeps your data volumes.
**PowerShell in Araiza/s1**
```powershell
.\scripts\cleanup.ps1 -Kubernetes
```

End the AWS lab and stop or terminate your EC2 instance when done.

### macOS startup

In Terminal, run `open -a Docker` and `brew services start jenkins-lts` if installed via Homebrew. Clone the same branch, use `cd Araiza/s1`, `bash scripts/setup.sh` and `curl`. The Docker, Minikube and kubectl commands are the same.
