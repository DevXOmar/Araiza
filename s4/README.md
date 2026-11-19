# SET-4 — Online Shopping Application

## Before starting

**Assigned source** [nikithamoturi/OnlineShoppingApp](https://github.com/nikithamoturi/OnlineShoppingApp), branch `main`.

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
cd Araiza\s4
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Keep this PowerShell open for the local steps.

| Open | URL |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose app | `http://127.0.0.1:8184/` |
| Minikube port-forward | `http://127.0.0.1:8314/` |
| Nagios | `http://127.0.0.1:8894/nagios/` |
| EC2 app | `http://PUBLIC_IP:8080/` |

## Q1 — Docker — Multi-Container Application

Run a standalone WordPress and MySQL site for product information. [compose.yaml](compose.yaml) sets up `s4-data-net`, matching credentials and `s4-db-data`.
**PowerShell in Araiza/s4**
```powershell
.\scripts\setup.ps1 -EnvOnly
docker compose pull
docker compose up -d --wait --wait-timeout 180
docker compose ps
docker compose logs --tail=10 web db
```

**Browser** Open [http://127.0.0.1:8184/wp-admin/install.php](http://127.0.0.1:8184/wp-admin/install.php). Install WordPress with site title **Product Information**, choose an admin username, password and email, and sign in. In **Pages → Add New**, create **Featured Products**. Add **Canvas tote and steel flask** and publish.

Run the first line and refresh to see the outage. Run the last two lines and refresh again.
**PowerShell in Araiza/s4**
```powershell
docker compose kill db
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
```

**Expected** Compose shows the renewed DB as healthy, and your published page still displays its sample content.

**Scenario questions**

**1. How would visitors be affected if the MySQL container becomes unavailable while the WordPress container is running?**<br>Dynamic product pages fail or report a database connection error while MySQL is down.<br><br>
**2. What is the consequence of running the MySQL container without a named volume and later removing that container?**<br>Rows stored only in the container are lost when it is removed, and an anonymous volume may not be reattached.<br><br>
**3. How do the Docker network and the MySQL container name help WordPress locate the database service?**<br>The user-defined network resolves the service name `db` to MySQL's current IP.<br><br>
**4. Which Docker commands can help identify whether WordPress failed to start because of a database connection problem?**<br>Run `docker compose ps`, `docker compose logs web db` and `docker compose exec web getent hosts db`.<br><br>
**5. What would you configure to run a second WordPress portal on the same Docker host without causing port or database conflicts?**<br>Use a different Compose project, host port, network names, volume names and database credentials.

## Q2 — Jenkins — Java Web Application Build and Continuous Integration

Build the assigned Java project and archive `OnlineShoppingApp.war`.

**Jenkins GUI** At [localhost:8080](http://localhost:8080/), install **Git and Maven Integration** under **Manage Jenkins → Plugins**. Under **Tools**, set **JDK21** and **Maven3** to your JDK and Maven installation folders, one level above `bin`.

1. **New Item → s4-freestyle → Freestyle project → OK**.
2. In **Configure → Source Code Management → Git**, use `https://github.com/nikithamoturi/OnlineShoppingApp.git`, no credentials, and branch `*/main`.
3. Under **Build Triggers → Poll SCM**, enter `H/5 * * * *`.
4. Under **Build Steps → Invoke top-level Maven targets**, choose **Maven3** and enter `clean test package`. Under **Post-build Actions → Archive the artifacts**, enter `target/OnlineShoppingApp.war`.
5. **Save → Build Now**. Open the run's **Console Output** and **Artifacts**.
6. For a red run add `-Dtest=MissingLabTest -Dsurefire.failIfNoSpecifiedTests=true` to the goals, save and build. Restore `clean test package` and build again.

**Expected** The failed run reports no matching test; the successful run archives `OnlineShoppingApp.war`. The upstream has no test classes.

**Scenario questions**

**1. How does an automated Jenkins build help detect defects before a shopping application update is released?**<br>The Freestyle job compiles, runs available checks and packages the selected revision before anyone releases it.<br><br>
**2. What is the effect on the build result if one of the test cases fails after successful compilation?**<br>Surefire exits nonzero, so Jenkins fails the run before creating or archiving the new WAR.<br><br>
**3. How does Maven simplify the management of libraries required by the shopping application?**<br>Maven obtains the declared libraries and transitive dependencies from repositories using POM versions.<br><br>
**4. How can Jenkins be configured to build only a selected branch containing a new shopping cart feature?**<br>Use the branch specifier `*/feature/cart` and point the job to the fork that has it.<br><br>
**5. Why is it useful to retain build history and WAR artifacts for earlier successful versions?**<br>Build history ties each WAR to its commit and gives the team known deployable versions for comparison or rollback.

## Q3 — Kubernetes — Container Deployment and Auto Scaling

Deploy the Java app with [deployment.yaml](k8s/deployment.yaml) and [service.yaml](k8s/service.yaml), then scale from 3 to 5 replicas.
**PowerShell in Araiza/s4**
```powershell
.\scripts\setup.ps1
minikube start --driver=docker
minikube image load araiza-s4:v1
```
**PowerShell in Araiza/s4**
```powershell
$ns = 'araiza-s4'
kubectl --context minikube apply -f k8s\namespace.yaml
kubectl --context minikube -n $ns apply -f k8s\deployment.yaml -f k8s\service.yaml
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get 'deploy,pods,svc'
```

Leave this port-forward to the NodePort Service running and open [the app](http://127.0.0.1:8314/).
**Second PowerShell, any folder**
```powershell
kubectl --context minikube -n araiza-s4 port-forward svc/araiza-s4 8314:8080
```

Back in the first window, scale and delete one Pod. Compare its name with the names after recovery.
**PowerShell in Araiza/s4**
```powershell
kubectl --context minikube -n $ns scale deployment/$ns --replicas=5
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
$pod = kubectl --context minikube -n $ns get pods -l "app=$ns" -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n $ns delete pod $pod
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get pods
```

**Expected** The Java app opens and 5 Pods become Ready with a new Pod name after deletion.

**Scenario questions**

**1. How does Kubernetes help maintain the availability of the shopping application when a pod fails?**<br>The Service keeps sending new requests to Ready Pods while the controller creates a replacement.<br><br>
**2. What is the relationship between a Deployment and the number of running replicas?**<br>The Deployment declares the desired replica count, and the ReplicaSet reconciles the matching Pods.<br><br>
**3. Why is scaling important for the shopping platform during a high-traffic sale?**<br>More replicas can serve more concurrent requests, provided the node and dependencies have capacity.<br><br>
**4. How does a Kubernetes Service route requests when the application is running in multiple pods?**<br>The Service selects Pods by label and routes through Ready EndpointSlice addresses.<br><br>
**5. How can the administrator undo an update that causes the shopping application to malfunction?**<br>Run `kubectl --context minikube -n araiza-s4 rollout undo deployment/araiza-s4` and verify the earlier image is serving.

## Q4 — Nagios — Infrastructure and Application Monitoring

Start Nagios with the checks supplied in [lab.cfg](nagios/lab.cfg). Keep the Compose app from Q1 available.
**PowerShell in Araiza/s4**
```powershell
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build --wait --wait-timeout 180
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
(Get-Content .env | Select-String '^NAGIOS_PASSWORD=').Line.Split('=', 2)[1]
```

**Browser** Open [Nagios](http://127.0.0.1:8894/nagios/) as `nagiosadmin` with the password above. Under **Services**, show **Portal HTTP**, **Database TCP**, CPU, memory, disk and uptime. WARNING / CRITICAL are 75% / 90% for CPU and memory, 80% / 95% disk, under 120s / 30s uptime, and 1s / 3s HTTP response time.

Run these lines individually. After each stop wait for CRITICAL (about a minute), then run its start and show recovery in **Alert History**.
**PowerShell in Araiza/s4**
```powershell
docker compose stop db
docker compose start db
docker compose stop web
docker compose start web
```

**Expected** Nagios validates with zero errors and records CRITICAL → OK for the database and HTTP checks.

**Scenario questions**

**1. How can Nagios help the support team identify resource pressure during a promotional sale?**<br>Check the CPU, memory and disk services for threshold crossings and confirm the portal latency.<br><br>
**2. What action should an administrator take when a monitored service changes from WARNING to CRITICAL?**<br>Treat CRITICAL as urgent and use related checks and logs to choose the corrective action.<br><br>
**3. How can Nagios detect an HTTP failure while the EC2 or application host is still reachable?**<br>The HTTP plugin evaluates status and latency independently of host reachability.<br><br>
**4. What are the risks of running the monitoring server without monitoring its own availability?**<br>A Nagios outage leaves services unmonitored unless an independent check detects it.<br><br>
**5. How would you isolate whether a shopping application outage is caused by Tomcat, MySQL or network connectivity?**<br>Compare Tomcat HTTP, WordPress HTTP and MySQL TCP, then check DNS and the host port.

## Q5 — AWS — Cloud Deployment using EC2

Deploy the assigned app to Ubuntu EC2.

**AWS console** [awsacademy.instructure.com](https://awsacademy.instructure.com/) → **Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved x86 instance, about **16 GiB gp3** if allowed, **public IPv4**, and a `.pem` key pair. Inbound rules are **TCP 22 from My IP** and **TCP 8080 from your or the examiner's IP**.
**PowerShell in Araiza/s4**
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
cd Araiza/s4
```

[deploy.sh](aws/deploy.sh) fetches the Java source, builds the WAR and starts Tomcat on port 8080.
**Ubuntu EC2 terminal, in Araiza/s4**
```bash
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

**Browser** Replace `PUBLIC_IP` in `http://PUBLIC_IP:8080/` with the EC2 address. If it fails, run `sudo journalctl -u araiza-s4-tomcat -n 60 --no-pager` in the Ubuntu SSH window and check the inbound rule.

**Expected** Your application opens at the public address.

**Scenario questions**

**1. What are the possible reasons that customers cannot access the shopping application using the EC2 public IP address?**<br>Verify correct public IPv4, TCP 8080 in the attached security group, route, guest firewall, and a working local Tomcat URL.<br><br>
**2. Why should SSH access be limited instead of allowing connections from all IP addresses?**<br>Limit SSH to administrators and reduce exposure to password guessing and scans.<br><br>
**3. What happens to customer requests if the Tomcat service fails but the EC2 instance remains in the running state?**<br>The instance stays up but Tomcat requests time out or are refused until the listener is restored.<br><br>
**4. How can the company improve application availability and handle traffic spikes during an online sale?**<br>Use health-checked replicas across Availability Zones and provision sufficient shared data capacity.<br><br>
**5. Why is a load balancer with multiple EC2 instances more suitable than a single EC2 instance for a growing e-commerce application?**<br>The ALB distributes load and removes failed targets, avoiding a single Tomcat instance as the only path to the store.

## Troubleshooting and cleanup

- **Port busy** Run `Get-NetTCPConnection -State Listen -LocalPort 8080,8184,8314,8894 -ErrorAction SilentlyContinue`. For a Compose port conflict, change `WEB_PORT` or `NAGIOS_PORT` in your local `.env` and use that port in the browser.
- **Container unhealthy** Run `docker compose logs --tail=40 web db`. For Jenkins errors, check **Console Output** and the names `JDK21` and `Maven3`.

Stop the port-forward with Ctrl+C. The cleanup command keeps your data volumes.
**PowerShell in Araiza/s4**
```powershell
.\scripts\cleanup.ps1 -Kubernetes
```

End the AWS lab and stop or terminate your EC2 instance when done.

### macOS startup

In Terminal, run `open -a Docker` and `brew services start jenkins-lts` if installed via Homebrew. Clone the same branch, use `cd Araiza/s4`, `bash scripts/setup.sh` and `curl`. The Docker, Minikube and kubectl commands are the same.
