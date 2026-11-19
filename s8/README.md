# SET-8 — Blood Bank Management System

## Before starting

**Assigned source** [sarasrija/BloodBanksystem](https://github.com/sarasrija/BloodBanksystem), branch `main`.

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
cd Araiza\s8
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Keep this PowerShell open for the local steps.

| Open | URL |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose app | `http://127.0.0.1:8188/` |
| Minikube port-forward | `http://127.0.0.1:8318/` |
| Nagios | `http://127.0.0.1:8898/nagios/` |
| EC2 app | `http://PUBLIC_IP/` or `http://PUBLIC_IP:8080/` for Tomcat |

## Q1 — Jenkins — Scripted Pipeline & Build Triggers

Build the assigned Java project and archive `bloodbank.war`.

**Jenkins GUI** At [localhost:8080](http://localhost:8080/), install **Pipeline, Git, GitHub and Pipeline Stage View** under **Manage Jenkins → Plugins**. Under **Tools**, set **JDK21** and **Maven3** to your JDK and Maven installation folders, one level above `bin`.
**PowerShell in Araiza/s8**
```powershell
Get-Content -Raw .\Jenkinsfile | Set-Clipboard
```

**Jenkins GUI**

1. **New Item → s8-pipeline → Pipeline → OK**. Under **Configure → Pipeline → Pipeline script**, paste the copied [Jenkinsfile](Jenkinsfile). Keep **Groovy Sandbox** checked.
2. Under **Build Triggers**, use **Poll SCM** with `H/5 * * * *`.
3. **Save → Build Now**. Under **Build History**, open **Console Output** and check **Artifacts**.
4. To show a red run, use **Build with Parameters**, set `SOURCE_BRANCH` to `no-such-lab-branch`, build once, then restore `main`.

The build logs its number and uses `SOURCE_DIR=bloodbankapp` for clean, install, test and package.

**Expected** Jenkins archives `bloodbank.war` from a successful run and shows each stage in Console Output.

**Scenario questions**

**1. The project folder name is not mavenjava but bloodbankapp—which parts of the script must you edit?**<br>Set only `SOURCE_DIR` to `bloodbankapp` because the build and archive paths both use it.<br><br>
**2. If the install stage fails, will the subsequent test and package stages still run in this scripted pipeline?**<br>A nonzero install exit fails the Pipeline and skips Test and Package.<br><br>
**3. Your test cases failed, but the pipeline still continued (or failed depending on configuration)—how does Jenkins handle step execution in the test stage?**<br>A failed `bat` command stops later stages unless the Pipeline explicitly catches the error.<br><br>
**4. If you want to print the current build number inside the console logs for auditing, how do you reference it in the pipeline script?**<br>Use `echo "Build #${env.BUILD_NUMBER}"`.<br><br>
**5. What is the role of Jenkins in a Continuous Integration pipeline?**<br>Jenkins retrieves changes, orchestrates repeatable builds and checks, and stores results and artifacts for review.

## Q2 — AWS — Cloud Deployment using EC2

Deploy a static page with Apache and the Java WAR with Tomcat.

To demonstrate first-boot setup, copy [user-data.sh](aws/user-data.sh) and paste it into **Advanced details → User data** when you launch the instance.
**PowerShell in Araiza/s8**
```powershell
(Get-Content -Raw .\aws\user-data.sh).Replace('git clone --depth 1 ', 'git clone --depth 1 --branch lab/nine-set-execution ') | Set-Clipboard
```

**AWS console** [awsacademy.instructure.com](https://awsacademy.instructure.com/) → **Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved x86 instance, about **16 GiB gp3** if allowed, **public IPv4**, and a `.pem` key pair. Inbound rules are **TCP 22 from My IP** and **TCP 80 for Apache and 8080 for Tomcat from your or the examiner's IP**.
**PowerShell in Araiza/s8**
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
cd Araiza/s8
```

[deploy-static.sh](aws/deploy-static.sh) installs [index.html](aws/index.html) in `/var/www/html`. [deploy.sh](aws/deploy.sh) builds and starts the WAR.
**Ubuntu EC2 terminal, in Araiza/s8**
```bash
bash aws/deploy-static.sh
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

If you used User Data, run `sudo cloud-init status --long` on EC2 to check it. User Data runs once by default; the enabled services start on later boots.

**Browser** Replace `PUBLIC_IP` in `http://PUBLIC_IP/` with the EC2 address. Also open `http://PUBLIC_IP:8080/` for Tomcat. If it fails, run `sudo journalctl -u apache2 -u araiza-s8-tomcat -n 60 --no-pager` in the Ubuntu SSH window and check the inbound rule.

**Expected** Apache and Tomcat both serve their pages.

**Scenario questions**

**1. You deployed your index.html or static assets to /var/www/html/ directory on EC2, but the web page still isn’t loading. What are two possible issues you would check?**<br>Check that Apache is running and `/var/www/html/index.html` is readable.<br><br>
**2. You have a simple index.html file on your laptop and you launched an EC2 instance. The instance is running, but when you open the public IP in a browser, the page doesn’t load. What initial steps will you take?**<br>From the set folder, upload with `scp -i ($pem.Trim('"')) .\aws\index.html "ubuntu@${ec2}:/tmp/index.html"`, then run `bash aws/deploy-static.sh /tmp/index.html` on EC2.<br><br>
**3. You can access your web application locally on the EC2 instance using curl localhost:8080, but not from your external browser. What AWS setting is likely missing or misconfigured?**<br>Allow inbound TCP 8080 from your IP on the instance's attached security group.<br><br>
**4. You want to automate the deployment of your web assets whenever you restart the EC2 instance. Which EC2 feature can be used to run setup commands automatically during instance startup?**<br>Use User Data for first boot and enable a systemd service for later boots.<br><br>
**5. Why should SSH access (Port 22) be restricted in security group settings?**<br>Keep SSH inbound limited to administrative IPs to reduce exposure to unauthorized access.

## Q3 — Kubernetes & Nagios — Minikube Pods & Infrastructure Monitoring

Deploy the Java app with [deployment.yaml](k8s/deployment.yaml) and [service.yaml](k8s/service.yaml), then scale from 2 to 4 replicas.
**PowerShell in Araiza/s8**
```powershell
.\scripts\setup.ps1
minikube start --driver=docker
minikube image load araiza-s8:v1
```
**PowerShell in Araiza/s8**
```powershell
$ns = 'araiza-s8'
kubectl --context minikube apply -f k8s\namespace.yaml
kubectl --context minikube -n $ns apply -f k8s\deployment.yaml -f k8s\service.yaml
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get 'deploy,pods,svc'
```

Leave this port-forward to the NodePort Service running and open [the app](http://127.0.0.1:8318/).
**Second PowerShell, any folder**
```powershell
kubectl --context minikube -n araiza-s8 port-forward svc/araiza-s8 8318:8080
```

Back in the first window, scale and delete one Pod. Compare its name with the names after recovery.
**PowerShell in Araiza/s8**
```powershell
kubectl --context minikube -n $ns scale deployment/$ns --replicas=4
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
$pod = kubectl --context minikube -n $ns get pods -l "app=$ns" -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n $ns delete pod $pod
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get pods
```

Update to v2, then undo the update. Relaunch the port-forward if its Pod was replaced.
**PowerShell in Araiza/s8**
```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s8:v2 .
minikube image load araiza-s8:v2
kubectl --context minikube -n $ns set image deployment/$ns web=araiza-s8:v2
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get deployment $ns -o wide
kubectl --context minikube -n $ns rollout undo deployment/$ns
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get deployment $ns -o wide
```

For troubleshooting, set `$pod` to the current failing Pod name from `get pods`.

**Expected** The Java app opens and 4 Pods become Ready with a new Pod name after deletion.

### Nagios

Start Nagios with the checks supplied in [lab.cfg](nagios/lab.cfg). This also starts the services used in Q4.
**PowerShell in Araiza/s8**
```powershell
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build --wait --wait-timeout 180
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
(Get-Content .env | Select-String '^NAGIOS_PASSWORD=').Line.Split('=', 2)[1]
```

**Browser** Open [Nagios](http://127.0.0.1:8898/nagios/) as `nagiosadmin` with the password above. Under **Services**, show **Portal HTTP**, **Database TCP**, CPU, memory, disk and uptime. WARNING / CRITICAL are 75% / 90% for CPU and memory, 80% / 95% disk, under 120s / 30s uptime, and 1s / 3s HTTP response time.

Run these lines individually. After each stop wait for CRITICAL (about a minute), then run its start and show recovery in **Alert History**.
**PowerShell in Araiza/s8**
```powershell
docker compose stop db
docker compose start db
docker compose stop web
docker compose start web
```

**Expected** Nagios validates with zero errors and records CRITICAL → OK for the database and HTTP checks.

**Scenario questions**

**1. How would you debug a failed deployment in Kubernetes using kubectl diagnostic commands?**<br>Run `kubectl --context minikube -n $ns describe pod $pod` and `kubectl --context minikube -n $ns get events`.<br><br>
**2. How do you roll back a faulty deployment in Kubernetes if an update introduces bugs?**<br>Run `kubectl --context minikube -n araiza-s8 rollout undo deployment/araiza-s8` and watch rollout status before testing.<br><br>
**3. How do you debug a running Pod when application-level errors occur inside the container?**<br>Run `kubectl --context minikube -n $ns logs $pod -c web --tail=60` with the failing Pod name.<br><br>
**4. How can you check whether the Nagios monitoring daemon/service is running properly on your system?**<br>Run `docker compose -f compose.yaml -f nagios/compose.yaml exec -T nagios sv status nagios` from this set.<br><br>
**5. What are the main advantages of using Nagios for IT infrastructure monitoring?**<br>Nagios centralizes active checks, resource thresholds, state transitions and incident history in one dashboard.

## Q4 — Docker Compose — Multi-Container Orchestration

Run the assigned Java app with PostgreSQL 15 and use the lab companion to save blood inventory. [compose.yaml](compose.yaml) sets up `s8-data-net` and `s8-db-data`. Reuse the setup from Q3.
**PowerShell in Araiza/s8**
```powershell
docker compose up -d --build --wait --wait-timeout 180
docker compose ps
```

**Browser** Open [http://127.0.0.1:8188/](http://127.0.0.1:8188/) for the Java app and [http://127.0.0.1:8188/lab/](http://127.0.0.1:8188/lab/) for the database form. Use sample data.
**PowerShell in Araiza/s8**
```powershell
$ref = 'Exam-' + (Get-Date -Format yyyyMMddHHmmss)
curl.exe -fsS -d "reference=$ref" --data-urlencode 'bloodGroup=O+' http://127.0.0.1:8188/lab/records
```

For a code change, use `docker compose up -d --build`. For a pause and resume, use `docker compose stop` then `docker compose start`.

Replace the database container and read the saved record again.
**PowerShell in Araiza/s8**
```powershell
docker compose stop db
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
curl.exe -fsS http://127.0.0.1:8188/lab/records
```

**Expected** Your `Exam-...` record survives DB replacement.

**Scenario questions**

**1. How do you stop and clean up your running container stack and remove associated resources without losing volume data?**<br>Run `docker compose down` without `-v` to remove containers and retain named volumes.<br><br>
**2. You updated some code and want to restart your frontend, backend, and DB containers quickly. What is the easiest way to manage this lifecycle?**<br>Run `docker compose up -d --build` for changed images, or `docker compose restart` for already-created containers.<br><br>
**3. How do you share your application configuration and code as an image bundle with a teammate using Docker images?**<br>Save both images with `docker image save -o "$env:TEMP/s8-images.tar" araiza-s8-compose:local araiza-s8-postgres:15` and use `docker image load` on the receiving machine.<br><br>
**4. What happens when you try to run two containers that expose the exact same port on the host machine?**<br>The second bind fails, so change `WEB_PORT` or free the existing port.<br><br>
**5. Why are networks specified in Docker Compose instead of relying solely on default bridge networking for interdependent services?**<br>The custom data network limits membership and gives the web service a stable `db` DNS address as containers change.

## Troubleshooting and cleanup

- **Port busy** Run `Get-NetTCPConnection -State Listen -LocalPort 8080,8188,8318,8898 -ErrorAction SilentlyContinue`. For a Compose port conflict, change `WEB_PORT` or `NAGIOS_PORT` in your local `.env` and use that port in the browser.
- **Container unhealthy** Run `docker compose logs --tail=40 web db`. For Jenkins errors, check **Console Output** and the names `JDK21` and `Maven3`.

Stop the port-forward with Ctrl+C. The cleanup command keeps your data volumes.
**PowerShell in Araiza/s8**
```powershell
.\scripts\cleanup.ps1 -Kubernetes
```

End the AWS lab and stop or terminate your EC2 instance when done.

### macOS startup

In Terminal, run `open -a Docker` and `brew services start jenkins-lts` if installed via Homebrew. Clone the same branch, use `cd Araiza/s8`, `bash scripts/setup.sh` and `curl`. The Docker, Minikube and kubectl commands are the same.
