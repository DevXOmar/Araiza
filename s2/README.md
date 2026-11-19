# SET-2 — Hospital Management System

## Before starting

**Assigned source** [ssvkotamraju/HMS](https://github.com/ssvkotamraju/HMS), branch `main`.

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
cd Araiza\s2
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Keep this PowerShell open for the local steps.

| Open | URL |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose app | `http://127.0.0.1:8182/` |
| Minikube port-forward | `http://127.0.0.1:8312/` |
| Nagios | `http://127.0.0.1:8892/nagios/` |
| EC2 app | `http://PUBLIC_IP:8080/` |

## Q1 — Docker — Multi-Container Application

Run the assigned Java app with PostgreSQL 15 and use the lab companion to save appointments. [compose.yaml](compose.yaml) sets up `hms-net` and `s2-db-data`.
**PowerShell in Araiza/s2**
```powershell
.\scripts\setup.ps1
docker compose up -d --build --wait --wait-timeout 180
docker compose ps
```

**Browser** Open [http://127.0.0.1:8182/](http://127.0.0.1:8182/) for the Java app and [http://127.0.0.1:8182/lab/](http://127.0.0.1:8182/lab/) for the database form. Use sample data.
**PowerShell in Araiza/s2**
```powershell
$ref = 'Exam-' + (Get-Date -Format yyyyMMddHHmmss)
curl.exe -fsS -d "reference=$ref" --data-urlencode 'department=General' http://127.0.0.1:8182/lab/records
```

Replace the database container and read the saved record again.
**PowerShell in Araiza/s2**
```powershell
docker compose stop db
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
curl.exe -fsS http://127.0.0.1:8182/lab/records
```
**PowerShell in Araiza/s2**
```powershell
docker compose up -d --no-deps --scale web=2 web
docker compose ps web proxy
```

**Expected** Your `Exam-...` record survives DB replacement, and the proxy serves two web containers.

**Scenario questions**

**1. What occurs if the database container crashes while a doctor is updating patient prescription details?**<br>Uncommitted prescription changes roll back, so verify stored state before resubmitting.<br><br>
**2. How can sensitive patient records be recovered following accidental container deletion?**<br>Reattach `s2-db-data` to PostgreSQL or restore a backup if that volume was lost.<br><br>
**3. Why is an isolated custom Docker network critical for a hospital application?**<br>`hms-net` limits container exposure and gives the HMS service stable DNS for the database.<br><br>
**4. How would you prevent unauthorized external access to the hospital database container?**<br>Keep PostgreSQL unpublished, limit network membership, and use the scoped role with a private generated password.<br><br>
**5. How would you deploy multiple HMS backend instances using Docker Compose for separate hospital departments?**<br>Scale with `docker compose up -d --no-deps --scale web=2 web` and apply department access controls separately.

## Q2 — Jenkins — Java Application Build and Continuous Integration

Build the assigned Java project and archive `LibraryRegistration.war`.

**Jenkins GUI** At [localhost:8080](http://localhost:8080/), install **Pipeline, Git, GitHub, JUnit and Pipeline Stage View** under **Manage Jenkins → Plugins**. Under **Tools**, set **JDK21** and **Maven3** to your JDK and Maven installation folders, one level above `bin`.
**PowerShell in Araiza/s2**
```powershell
$job = Get-Content -Raw .\Jenkinsfile
$job = $job.Replace("'LAB_BRANCH', defaultValue: 'main'", "'LAB_BRANCH', defaultValue: 'lab/nine-set-execution'")
$job | Set-Clipboard
```

**Jenkins GUI**

1. **New Item → s2-pipeline → Pipeline → OK**. Under **Configure → Pipeline → Pipeline script**, paste the copied [Jenkinsfile](Jenkinsfile). Keep **Groovy Sandbox** checked.
2. Under **Build Triggers**, use **Poll SCM** with `H/5 * * * *`.
3. **Save → Build Now**. Under **Build History**, open **Console Output** and check **Artifacts**.
4. **Build with Parameters → FAIL_TEST → Build** makes a red JUnit run. Clear `FAIL_TEST` for the next run. The copied script already sets `LAB_BRANCH` to `lab/nine-set-execution`.

For a GitHub push demo, set the job script's `SOURCE_URL` default to your fork, switch the trigger to **GitHub hook trigger for GITScm polling**, and run once. In the fork use **Settings → Webhooks → Add webhook**, a reachable Jenkins HTTPS URL ending in `/github-webhook/`, **application/json**, and **Just the push event**.

**PRs into main** Install [Generic Webhook Trigger](https://plugins.jenkins.io/generic-webhook-trigger/) and use a separate Pipeline called `s2-hms-main-pr`. Copy [Jenkinsfile.pr](Jenkinsfile.pr), paste it as the Pipeline script, and change its URL to your HMS fork.
**PowerShell in Araiza/s2**
```powershell
Get-Content -Raw .\Jenkinsfile.pr | Set-Clipboard
```

1. In **Manage Jenkins → Nodes**, use an isolated agent labeled `pr-isolated` with Git, Java and Maven. In **Manage Jenkins → Credentials** add a **Secret text** token.
2. In the PR job's **Configure → Build Triggers → Generic Webhook Trigger**, select that token. Add POST JSONPath mappings `PR_REPO=$.repository.full_name`, `PR_BASE=$.pull_request.base.ref`, `PR_NUMBER=$.number`, `PR_ACTION=$.action`.
3. Filter `$PR_REPO:$PR_BASE:$PR_ACTION` with `^YOUR_OWNER/HMS:main:(opened|reopened|synchronize|ready_for_review)$`, using your fork's owner and name.
4. Add a **Pull requests** JSON webhook at `https://YOUR_JENKINS/generic-webhook-trigger/invoke?token=YOUR_TOKEN`. Open mergeable PRs into `main` and another branch. Only the first should build.

**Expected** The green run archives `LibraryRegistration.war` and the red run stops at the intended failure.

**Scenario questions**

**1. How does Jenkins highlight compilation errors in the HMS source code?**<br>Console Output shows the Maven compiler error, source file and line.<br><br>
**2. What is the pipeline behavior if code compiles successfully, but patient data validation test cases fail?**<br>A failed validation test stops WAR packaging while Jenkins retains the JUnit result.<br><br>
**3. Why is Maven utilized instead of manual dependency management for hospital libraries?**<br>Maven records versions centrally and resolves transitive dependencies consistently on each agent.<br><br>
**4. How can Jenkins be configured to build only pull requests targeting the main branch?**<br>Use the separate PR job above to filter `$.pull_request.base.ref` to `main` before fetching the merge ref.<br><br>
**5. What is the operational distinction between Continuous Integration and Continuous Deployment in a clinical software lifecycle?**<br>CI compiles and tests each change, while Continuous Deployment releases changes that pass.

## Q3 — Kubernetes — Container Deployment and Auto Scaling

Deploy the Java app with [deployment.yaml](k8s/deployment.yaml) and [service.yaml](k8s/service.yaml), then scale from 2 to 5 replicas.
**PowerShell in Araiza/s2**
```powershell
.\scripts\setup.ps1
minikube start --driver=docker
minikube image load araiza-s2:v1
```
**PowerShell in Araiza/s2**
```powershell
$ns = 'araiza-s2'
kubectl --context minikube apply -f k8s\namespace.yaml
kubectl --context minikube -n $ns apply -f k8s\deployment.yaml -f k8s\service.yaml
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get 'deploy,pods,svc'
```

Leave this port-forward to the NodePort Service running and open [the app](http://127.0.0.1:8312/).
**Second PowerShell, any folder**
```powershell
kubectl --context minikube -n araiza-s2 port-forward svc/araiza-s2 8312:8080
```

Back in the first window, scale and delete one Pod. Compare its name with the names after recovery.
**PowerShell in Araiza/s2**
```powershell
kubectl --context minikube -n $ns scale deployment/$ns --replicas=5
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
$pod = kubectl --context minikube -n $ns get pods -l "app=$ns" -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n $ns delete pod $pod
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get pods
```

Update to v2, then undo the update. Relaunch the port-forward if its Pod was replaced.
**PowerShell in Araiza/s2**
```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s2:v2 .
minikube image load araiza-s2:v2
kubectl --context minikube -n $ns set image deployment/$ns web=araiza-s2:v2
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get deployment $ns -o wide
kubectl --context minikube -n $ns rollout undo deployment/$ns
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get deployment $ns -o wide
```

**Expected** The Java app opens and 5 Pods become Ready with a new Pod name after deletion.

**Scenario questions**

**1. What happens when a pod hosting the patient registration portal crashes?**<br>Kubernetes recovers the Pod while the Service routes new requests to other Ready replicas.<br><br>
**2. How does the Kubernetes control plane sustain the specified replica count?**<br>The Deployment maintains a ReplicaSet whose controller reconciles Pods to the requested count.<br><br>
**3. What differentiates manual scaling from automated Horizontal Pod Autoscaling?**<br>Manual scaling sets a fixed replica count, while the optional [HPA](k8s/hpa.yaml) uses CPU metrics to adjust it.<br><br>
**4. Why is a Kubernetes Service essential for internal microservice communication in the hospital system?**<br>A Service gives clients stable DNS and forwards to Ready Pods as their IP addresses change.<br><br>
**5. How can you recover from a failed HMS update using kubectl rollout undo?**<br>Run `kubectl --context minikube -n araiza-s2 rollout undo deployment/araiza-s2`, then confirm rollout and verify HTTP.

## Q4 — Nagios — Infrastructure and Application Monitoring

Start Nagios with the checks supplied in [lab.cfg](nagios/lab.cfg). Keep the Compose app from Q1 available.
**PowerShell in Araiza/s2**
```powershell
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build --wait --wait-timeout 180
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
(Get-Content .env | Select-String '^NAGIOS_PASSWORD=').Line.Split('=', 2)[1]
```

**Browser** Open [Nagios](http://127.0.0.1:8892/nagios/) as `nagiosadmin` with the password above. Under **Services**, show **Portal HTTP**, **Database TCP**, CPU, memory, disk and uptime. WARNING / CRITICAL are 65% / 85% for CPU and memory, 80% / 95% disk, under 120s / 30s uptime, and 1s / 3s HTTP response time.

Run these lines individually. After each stop wait for CRITICAL (about a minute), then run its start and show recovery in **Alert History**.
**PowerShell in Araiza/s2**
```powershell
docker compose stop db
docker compose start db
docker compose stop web
docker compose start web
```

**Expected** Nagios validates with zero errors and records CRITICAL → OK for the database and HTTP checks.

**Scenario questions**

**1. How does Nagios detect abnormal memory consumption on the hospital server?**<br>Nagios checks available memory and warns at 65% used or marks it critical at 85%.<br><br>
**2. What is the operational significance of moving from a WARNING state to a CRITICAL state in a hospital environment?**<br>Investigate WARNING as early pressure and act on CRITICAL as a severe threshold or outage.<br><br>
**3. How can Nagios identify application-level database failures when the underlying server operating system is healthy?**<br>`/lab/health` executes SQL and returns 503 on query failure even with an open DB port.<br><br>
**4. What happens to alert notifications if the Nagios monitoring container experiences a failure?**<br>Checks and alerts stop, so use an independent monitor to detect Nagios failure.<br><br>
**5. How would you trace downtime symptoms to isolate whether the root cause is Tomcat, MySQL, or hospital network switches?**<br>Compare HTTP, SQL health and DB TCP, then check client routing if the internal checks pass.

## Q5 — AWS — Cloud Deployment using EC2

Deploy the assigned app to Ubuntu EC2.

**AWS console** [awsacademy.instructure.com](https://awsacademy.instructure.com/) → **Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved x86 instance, about **16 GiB gp3** if allowed, **public IPv4**, and a `.pem` key pair. Inbound rules are **TCP 22 from My IP** and **TCP 8080 from your or the examiner's IP**.
**PowerShell in Araiza/s2**
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
cd Araiza/s2
```

[deploy.sh](aws/deploy.sh) fetches the Java source, builds the WAR and starts Tomcat on port 8080.
**Ubuntu EC2 terminal, in Araiza/s2**
```bash
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
curl -fsS http://127.0.0.1:8080/lab/health
```

The script configures PostgreSQL and its JDBC settings in `/etc/araiza-s2-db.env`. In **EC2 → Instances → Monitoring** check CPU usage and status, then show `CPUUtilization` and `StatusCheckFailed` for your instance under **CloudWatch → Metrics → EC2 → Per-Instance Metrics**.

**Browser** Replace `PUBLIC_IP` in `http://PUBLIC_IP:8080/` with the EC2 address. If it fails, run `sudo journalctl -u araiza-s2-tomcat -n 60 --no-pager` in the Ubuntu SSH window and check the inbound rule.

**Expected** Your application opens at the public address.

**Scenario questions**

**1. What AWS Security Group misconfigurations could block clinical staff from accessing the application browser?**<br>Compare local curl against the public IP, the security group's TCP 8080 source and the network route.<br><br>
**2. Why should SSH access (Port 22) be heavily restricted rather than opened to 0.0.0.0/0?**<br>Restrict port 22 to the admin's IP to limit login attempts and reduce exposure.<br><br>
**3. What happens to active doctor sessions if the Tomcat service stops unexpectedly on EC2?**<br>In-memory doctor sessions may be lost, while PostgreSQL retains committed records.<br><br>
**4. How can application availability and disaster recovery be enhanced beyond a single EC2 instance?**<br>Use tested DB backups and failover, multiple application instances across zones, and externalized state where required.<br><br>
**5. Why would combining an Application Load Balancer with multiple EC2 instances be preferred over a single EC2 instance for a critical hospital system?**<br>An ALB sends traffic to healthy instances and enables rolling replacement or scale-out without depending on one VM.

## Troubleshooting and cleanup

- **Port busy** Run `Get-NetTCPConnection -State Listen -LocalPort 8080,8182,8312,8892 -ErrorAction SilentlyContinue`. For a Compose port conflict, change `WEB_PORT` or `NAGIOS_PORT` in your local `.env` and use that port in the browser.
- **Container unhealthy** Run `docker compose logs --tail=40 web db`. For Jenkins errors, check **Console Output** and the names `JDK21` and `Maven3`.

Stop the port-forward with Ctrl+C. The cleanup command keeps your data volumes.
**PowerShell in Araiza/s2**
```powershell
.\scripts\cleanup.ps1 -Kubernetes
```

End the AWS lab and stop or terminate your EC2 instance when done.

### macOS startup

In Terminal, run `open -a Docker` and `brew services start jenkins-lts` if installed via Homebrew. Clone the same branch, use `cd Araiza/s2`, `bash scripts/setup.sh` and `curl`. The Docker, Minikube and kubectl commands are the same.
