# SET-9 — Apartment Management System

## Before starting

**Assigned source** [sarasrija/ApartmentSystem](https://github.com/sarasrija/ApartmentSystem), branch `main`.

Install [Git](https://git-scm.com/downloads), [JDK 21](https://adoptium.net/temurin/releases/?version=21), [Maven](https://maven.apache.org/download.cgi), [Jenkins LTS](https://www.jenkins.io/download/), [Docker Desktop](https://www.docker.com/products/docker-desktop/) [Minikube](https://minikube.sigs.k8s.io/docs/start/) and [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/). Use [Windows OpenSSH](https://learn.microsoft.com/windows-server/administration/openssh/openssh_install_firstuse) for EC2 and install [ngrok](https://ngrok.com/download) for Q1.

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
cd Araiza\s9
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Keep this PowerShell open for the local steps.

| Open | URL |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose app | `http://127.0.0.1:8189/` |
| Minikube port-forward | `http://127.0.0.1:8319/` |
| Nagios | `http://127.0.0.1:8899/nagios/` |
| Jenkins Tomcat | `http://127.0.0.1:8199/` |
| EC2 app | `http://PUBLIC_IP:8090/` |

## Q1 — Jenkins — Web Application Build and Continuous Integration

Build the assigned Java project and archive `apartmentsystem.war`.

**Jenkins GUI** At [localhost:8080](http://localhost:8080/), install **Pipeline, Git, GitHub and Pipeline Stage View** under **Manage Jenkins → Plugins**. Under **Tools**, set **JDK21** and **Maven3** to your JDK and Maven installation folders, one level above `bin`.
**PowerShell in Araiza/s9**
```powershell
docker run -d --name s9-jenkins-tomcat -p 127.0.0.1:8199:8080 tomcat:9.0-jre17-temurin-noble
```

**GitHub** Fork the assigned repo. Copy its HTTPS clone URL.
**PowerShell in Araiza/s9**
```powershell
$fork = Read-Host 'HTTPS clone URL of your ApartmentSystem fork'
(Get-Content -Raw .\Jenkinsfile).Replace('https://github.com/sarasrija/ApartmentSystem.git', $fork) | Set-Clipboard
```

**Jenkins GUI**

1. **New Item → s9-pipeline → Pipeline → OK**. Under **Configure → Pipeline → Pipeline script**, paste the copied [Jenkinsfile](Jenkinsfile). Keep **Groovy Sandbox** checked. Enable **GitHub hook trigger for GITScm polling**.
2. **Save → Build Now**. Check **Stage View**, **Build History** and **Artifacts**. Open [Tomcat on 8199](http://127.0.0.1:8199/). For a reversible red run, manually use `SOURCE_BRANCH=no-such-lab-branch` once, then use `main`.
3. To create the view, use **Dashboard → + New View → List View**, name it `Apartment-CI`, and select `s9-pipeline`.
4. Start ngrok and keep its window open.
**Second PowerShell in Araiza/s9**
```powershell
ngrok config add-authtoken (Read-Host 'Paste your ngrok authtoken')
ngrok http 8080
```

**GitHub** On the fork go to **Settings → Webhooks → Add webhook**. Use ngrok's HTTPS forwarding URL plus `/github-webhook/`, **application/json**, and **Just the push event**. Commit a small change to `main` in your fork. Check **Recent Deliveries**, [ngrok requests](http://127.0.0.1:4040/), and Jenkins **Build History** for the new run.

**Expected** Jenkins archives `apartmentsystem.war` from a successful run, deploys it to port 8199, and records your webhook build.

**Scenario questions**

**1. After setting up the GitHub webhook, you push code changes, but Jenkins does not trigger automatically. What simple check would you perform on the ngrok terminal session to ensure it is still running and forwarding requests?**<br>Confirm the forwarding line points to localhost:8080 and the inspector at `127.0.0.1:4040` shows the webhook POST.<br><br>
**2. How does Jenkins display compilation errors in the console output when a syntax mistake is made in a Java file?**<br>Read the Jenkins Console Output for Maven's compiler error, file, line and column.<br><br>
**3. If the code compiles but a unit test fails, will Jenkins create a new WAR?**<br>No new WAR is packaged on a normal test failure because Maven stops at the test phase.<br><br>
**4. Why is ngrok necessary when connecting a local Jenkins server to GitHub webhooks?**<br>ngrok gives GitHub a public HTTPS address that forwards to local Jenkins.<br><br>
**5. What is the difference between Continuous Integration and Continuous Deployment?**<br>CI builds and verifies commits, while Continuous Deployment releases changes that pass.

## Q2 — AWS — Cloud Deployment using EC2

Deploy the assigned app to Ubuntu EC2.

**AWS console** [awsacademy.instructure.com](https://awsacademy.instructure.com/) → **Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved x86 instance such as t2.micro if offered, about **16 GiB gp3** if allowed, **public IPv4**, and a `.pem` key pair. Inbound rules are **TCP 22 from My IP** and **TCP 8090 from your or the examiner's IP**.
**PowerShell in Araiza/s9**
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
cd Araiza/s9
```

[deploy.sh](aws/deploy.sh) installs Docker, builds the included [Dockerfile](Dockerfile) and maps EC2 port 8090 to Tomcat port 8080.
**Ubuntu EC2 terminal, in Araiza/s9**
```bash
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8090/
```

**Browser** Replace `PUBLIC_IP` in `http://PUBLIC_IP:8090/` with the EC2 address. If it fails, run `sudo docker logs --tail=60 araiza-s9-ec2` in the Ubuntu SSH window and check the inbound rule.

**Expected** Your application opens at the public address.

**Scenario questions**

**1. Your container is running on port 8090 inside EC2, but you try to open port 8080 in your browser URL. What type of connection error do you get, and which AWS setting must you update in the Security Group?**<br>Port 8080 can time out or refuse the connection, so allow TCP 8090 and open `http://PUBLIC_IP:8090/`.<br><br>
**2. Why is leaving SSH access (Port 22) open to everyone (0.0.0.0/0) considered a security risk in AWS Security Groups?**<br>Opening TCP 22 to everyone exposes the administrative listener to scanning and login attempts.<br><br>
**3. What are the basic Linux shell commands used to refresh packages and install Docker on a new Ubuntu EC2 instance?**<br>On Ubuntu run `sudo apt-get update` followed by `sudo apt-get install -y docker.io git` and `sudo systemctl enable --now docker`.<br><br>
**4. If the Tomcat server inside your running container crashes unexpectedly, how can you view the container logs to find out what went wrong?**<br>On Ubuntu run `sudo docker ps -a --filter name=araiza-s9-ec2` and `sudo docker logs --tail=80 araiza-s9-ec2`.<br><br>
**5. How can application availability be improved?**<br>Use multiple instances across zones with an ALB, health checks, backups and an independent data store.

## Q3 — Kubernetes — Container Deployment and Auto Scaling

Deploy the Java app with [deployment.yaml](k8s/deployment.yaml) and [service.yaml](k8s/service.yaml), then scale from 4 to 6 replicas.
**PowerShell in Araiza/s9**
```powershell
.\scripts\setup.ps1
minikube start --driver=docker
minikube image load araiza-s9:v1
```
**PowerShell in Araiza/s9**
```powershell
$ns = 'araiza-s9'
kubectl --context minikube apply -f k8s\namespace.yaml
kubectl --context minikube -n $ns apply -f k8s\deployment.yaml -f k8s\service.yaml
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get 'deploy,pods,svc'
```

Leave this port-forward to the NodePort Service running and open [the app](http://127.0.0.1:8319/).
**Second PowerShell, any folder**
```powershell
kubectl --context minikube -n araiza-s9 port-forward svc/araiza-s9 8319:8080
```

Back in the first window, scale and delete one Pod. Compare its name with the names after recovery.
**PowerShell in Araiza/s9**
```powershell
kubectl --context minikube -n $ns scale deployment/$ns --replicas=6
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
$pod = kubectl --context minikube -n $ns get pods -l "app=$ns" -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n $ns delete pod $pod
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get pods
```

**Expected** The Java app opens and 6 Pods become Ready with a new Pod name after deletion.

### Nagios

Start Nagios with the checks supplied in [lab.cfg](nagios/lab.cfg). This also starts the services used in Q4.
**PowerShell in Araiza/s9**
```powershell
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build --wait --wait-timeout 180
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
(Get-Content .env | Select-String '^NAGIOS_PASSWORD=').Line.Split('=', 2)[1]
```

**Browser** Open [Nagios](http://127.0.0.1:8899/nagios/) as `nagiosadmin` with the password above. Under **Services**, show **Portal HTTP**, **Database TCP**, CPU, memory, disk and uptime. WARNING / CRITICAL are 75% / 90% for CPU and memory, 80% / 95% disk, under 120s / 30s uptime, and 1s / 3s HTTP response time.

Run these lines individually. After each stop wait for CRITICAL (about a minute), then run its start and show recovery in **Alert History**.
**PowerShell in Araiza/s9**
```powershell
docker compose stop db
docker compose start db
docker compose stop web
docker compose start web
```

**Expected** Nagios validates with zero errors and records CRITICAL → OK for the database and HTTP checks.

**Scenario questions**

**1. If one of your application pods stops working suddenly due to a crash, how does Kubernetes handle it to maintain the required number of replicas?**<br>The kubelet restarts a failed container, and the ReplicaSet replaces a lost Pod while Ready replicas keep serving.<br><br>
**2. What is the basic difference between a Pod IP address and a Service IP address when routing traffic?**<br>A Pod IP can change when that Pod is replaced, while the Service IP remains stable.<br><br>
**3. Which kubectl command is used to check the list of currently running pods and their statuses?**<br>Run `kubectl --context minikube -n araiza-s9 get pods -o wide`.<br><br>
**4. If you cannot open the NodePort page directly in your browser, what alternative command (kubectl port-forward) can you use to test the app locally?**<br>Run `kubectl --context minikube -n araiza-s9 port-forward service/araiza-s9 8319:8080` and open `http://127.0.0.1:8319/`.<br><br>
**5. How can Nagios identify application failure when the server is running?**<br>Nagios requests the portal's HTTP endpoint and flags error status or excessive latency separately from host liveness.

## Q4 — Docker Compose — Multi-Container Application

Run the assigned Java app with PostgreSQL 15 and use the lab companion to save maintenance requests. [compose.yaml](compose.yaml) sets up `s9-data-net` and `s9-db-data`. Reuse the setup from Q3.
**PowerShell in Araiza/s9**
```powershell
docker compose up -d --build --wait --wait-timeout 180
docker compose ps
```

**Browser** Open [http://127.0.0.1:8189/](http://127.0.0.1:8189/) for the Java app and [http://127.0.0.1:8189/lab/](http://127.0.0.1:8189/lab/) for the database form. Use sample data.
**PowerShell in Araiza/s9**
```powershell
$ref = 'Exam-' + (Get-Date -Format yyyyMMddHHmmss)
curl.exe -fsS -d "reference=$ref" --data-urlencode 'unit=B-12' http://127.0.0.1:8189/lab/records
```

For a code change, use `docker compose up -d --build`. For a pause and resume, use `docker compose stop` then `docker compose start`.

Replace the database container and read the saved record again.
**PowerShell in Araiza/s9**
```powershell
docker compose stop db
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
curl.exe -fsS http://127.0.0.1:8189/lab/records
```

**Expected** Your `Exam-...` record survives DB replacement.

**Scenario questions**

**1. What is the main use of the depends_on setting in a docker-compose.yml file?**<br>`depends_on` with `service_healthy` waits for the DB's authenticated SQL check before starting Tomcat.<br><br>
**2. Why do we configure persistent volumes for databases in Docker Compose, and what happens to saved records if volumes are left out when running docker compose down?**<br>The named volume preserves PostgreSQL data after `down`, while a replacement without that volume can initialize empty.<br><br>
**3. When you update your source code and run docker compose up -d, why don't the changes show up right away, and what flag should you add to rebuild everything?**<br>Use `docker compose up -d --build` to rebuild the image from changed source.<br><br>
**4. How do custom networks help containers find and talk to each other using names instead of IP addresses?**<br>Docker DNS resolves `db` on the shared data network, even when its IP changes.<br><br>
**5. How can database information be recovered after container deletion?**<br>Reattach `s9-db-data` with the original credentials, or restore a dump if the volume was lost.

## Troubleshooting and cleanup

- **Port busy** Run `Get-NetTCPConnection -State Listen -LocalPort 8080,8189,8319,8899,8199 -ErrorAction SilentlyContinue`. For a Compose port conflict, change `WEB_PORT` or `NAGIOS_PORT` in your local `.env` and use that port in the browser.
- **Container unhealthy** Run `docker compose logs --tail=40 web db`. For Jenkins errors, check **Console Output** and the names `JDK21` and `Maven3`. If Jenkins cannot deploy, use an agent account with Docker Desktop access. If the Tomcat container already exists, run `docker start s9-jenkins-tomcat`.

Stop the port-forward and ngrok tunnel with Ctrl+C. The cleanup command keeps your data volumes.
**PowerShell in Araiza/s9**
```powershell
.\scripts\cleanup.ps1 -Kubernetes
docker rm -f s9-jenkins-tomcat
```

End the AWS lab and stop or terminate your EC2 instance when done.

### macOS startup

In Terminal, run `open -a Docker` and `brew services start jenkins-lts` if installed via Homebrew. Clone the same branch, use `cd Araiza/s9`, `bash scripts/setup.sh` and `curl`. The Docker, Minikube and kubectl commands are the same.
