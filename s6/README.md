# SET-6 — Vehicle Rental Management System

## Before starting

**Assigned source** [nikithamoturi/VehicleRentalManagementSystem](https://github.com/nikithamoturi/VehicleRentalManagementSystem), branch `main`.

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
cd Araiza\s6
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Keep this PowerShell open for the local steps.

| Open | URL |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose app | `http://127.0.0.1:8186/` |
| Minikube port-forward | `http://127.0.0.1:8316/` |
| Nagios | `http://127.0.0.1:8896/nagios/` |
| EC2 app | `http://PUBLIC_IP:8080/` |

## Q1 — Docker — Multi-Container Application

Run a standalone WordPress and MySQL site for vehicle rental information. [compose.yaml](compose.yaml) sets up `s6-data-net`, matching credentials and `s6-db-data`.
**PowerShell in Araiza/s6**
```powershell
.\scripts\setup.ps1 -EnvOnly
docker compose pull
docker compose up -d --wait --wait-timeout 180
docker compose ps
docker compose logs --tail=10 web db
```

**Browser** Open [http://127.0.0.1:8186/wp-admin/install.php](http://127.0.0.1:8186/wp-admin/install.php). Install WordPress with site title **Vehicle Rental Information**, choose an admin username, password and email, and sign in. In **Pages → Add New**, create **Vehicles and Rental Policies**. Add **Airport pickup and compact car rentals** and publish.

Run the first line and refresh to see the outage. Run the last two lines and refresh again.
**PowerShell in Araiza/s6**
```powershell
docker compose kill db
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
```

**Expected** Compose shows the renewed DB as healthy, and your published page still displays its sample content.

**Scenario questions**

**1. What problem may occur if the WordPress container starts before the MySQL service is ready?**<br>WordPress may show a DB connection error before MySQL can accept authenticated queries.<br><br>
**2. How can WordPress connect to the MySQL container by using its container name instead of a changing IP address?**<br>Docker DNS resolves `db` to MySQL's current address on the shared network.<br><br>
**3. Why must the database name and login credentials configured for WordPress match those configured in MySQL?**<br>MySQL rejects the connection or database selection when the configured account or database differs.<br><br>
**4. What change would you make if the selected host port for the WordPress website is already being used by another application?**<br>Change `WEB_PORT` in `.env`, rerun Compose and browse to the new host port.<br><br>
**5. How do named volumes help the company retain portal information when the database container is replaced?**<br>Compose attaches `s6-db-data` to the replacement and preserves its SQL files.

## Q2 — Jenkins — Web Application Build and Continuous Integration

Build the assigned Java project and archive `VehicleRentalManagement.war`.

**Jenkins GUI** At [localhost:8080](http://localhost:8080/), install **Git and Maven Integration** under **Manage Jenkins → Plugins**. Under **Tools**, set **JDK21** and **Maven3** to your JDK and Maven installation folders, one level above `bin`.

1. **New Item → s6-freestyle → Freestyle project → OK**.
2. In **Configure → Source Code Management → Git**, use `https://github.com/nikithamoturi/VehicleRentalManagementSystem.git`, no credentials, and branch `*/main`.
3. Under **Build Triggers → Poll SCM**, enter `H/5 * * * *`.
4. Under **Build Steps → Invoke top-level Maven targets**, choose **Maven3** and enter `clean test package`. Under **Post-build Actions → Archive the artifacts**, enter `target/VehicleRentalManagement.war`.
5. **Save → Build Now**. Open the run's **Console Output** and **Artifacts**.
6. For a red run add `-Dtest=MissingLabTest -Dsurefire.failIfNoSpecifiedTests=true` to the goals, save and build. Restore `clean test package` and build again.

**Expected** The failed run reports no matching test; the successful run archives `VehicleRentalManagement.war`. The upstream has no test classes.

**Scenario questions**

**1. How would Jenkins help developers detect an error introduced while changing the vehicle booking process?**<br>Jenkins runs Maven after checking out the branch so it reports compilation or test failures on the originating build.<br><br>
**2. What should the team check when a Maven build fails because a dependency cannot be resolved?**<br>Check the dependency version and repository in Console Output, then check network, mirror and proxy settings.<br><br>
**3. Why should test execution be included in the automated build of a rental application?**<br>Automated tests catch rental workflow regressions before a WAR is released.<br><br>
**4. How can the Freestyle Project be restricted to build a feature branch instead of the main branch?**<br>Point Git SCM to the correct fork and use the exact branch specifier such as `*/feature/vehicles`.<br><br>
**5. What is the benefit of archiving the WAR file for each successful Jenkins build?**<br>A retained WAR can be traced to its successful build and reused for deployment or rollback.

## Q3 — Kubernetes — Container Deployment and Auto Scaling

Deploy the Java app with [deployment.yaml](k8s/deployment.yaml) and [service.yaml](k8s/service.yaml), then scale from 2 to 4 replicas.
**PowerShell in Araiza/s6**
```powershell
.\scripts\setup.ps1
minikube start --driver=docker
minikube image load araiza-s6:v1
```
**PowerShell in Araiza/s6**
```powershell
$ns = 'araiza-s6'
kubectl --context minikube apply -f k8s\namespace.yaml
kubectl --context minikube -n $ns apply -f k8s\deployment.yaml -f k8s\service.yaml
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get 'deploy,pods,svc'
```

Leave this port-forward to the NodePort Service running and open [the app](http://127.0.0.1:8316/).
**Second PowerShell, any folder**
```powershell
kubectl --context minikube -n araiza-s6 port-forward svc/araiza-s6 8316:8080
```

Back in the first window, scale and delete one Pod. Compare its name with the names after recovery.
**PowerShell in Araiza/s6**
```powershell
kubectl --context minikube -n $ns scale deployment/$ns --replicas=4
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
$pod = kubectl --context minikube -n $ns get pods -l "app=$ns" -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n $ns delete pod $pod
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get pods
```

Try a missing image tag. Expect the wait to time out and rollback to restore the Ready Pods.
**PowerShell in Araiza/s6**
```powershell
kubectl --context minikube -n $ns set image deployment/$ns web=araiza-s6:missing-drill
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=45s
kubectl --context minikube -n $ns get pods
kubectl --context minikube -n $ns rollout undo deployment/$ns
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
```

**Expected** The Java app opens and 4 Pods become Ready with a new Pod name after deletion.

**Scenario questions**

**1. How does Kubernetes help keep the rental portal available when an application pod terminates?**<br>The Service keeps routing to Ready Pods while the controller replaces the terminated replica.<br><br>
**2. What is the purpose of specifying a replica count in a Deployment?**<br>The replica count is the desired number of Pods maintained by the ReplicaSet.<br><br>
**3. Why may the company need to scale the rental portal during holiday seasons?**<br>Scaling increases capacity during holiday demand, subject to resource and dependency constraints.<br><br>
**4. How does a Service provide a stable access point when pod IP addresses change?**<br>The Service address persists while EndpointSlices are updated for new Pod addresses.<br><br>
**5. What steps can be taken if the latest application image introduces an error after deployment?**<br>Check `kubectl --context minikube -n araiza-s6 get events`, then run `kubectl --context minikube -n araiza-s6 rollout undo deployment/araiza-s6`.

## Q4 — Nagios — Infrastructure and Application Monitoring

Start Nagios with the checks supplied in [lab.cfg](nagios/lab.cfg). Keep the Compose app from Q1 available.
**PowerShell in Araiza/s6**
```powershell
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build --wait --wait-timeout 180
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
(Get-Content .env | Select-String '^NAGIOS_PASSWORD=').Line.Split('=', 2)[1]
```

**Browser** Open [Nagios](http://127.0.0.1:8896/nagios/) as `nagiosadmin` with the password above. Under **Services**, show **Portal HTTP**, **Database TCP**, CPU, memory, disk and uptime. WARNING / CRITICAL are 75% / 90% for CPU and memory, 80% / 95% disk, under 120s / 30s uptime, and 1s / 3s HTTP response time.

Run these lines individually. After each stop wait for CRITICAL (about a minute), then run its start and show recovery in **Alert History**.
**PowerShell in Araiza/s6**
```powershell
docker compose stop db
docker compose start db
docker compose stop web
docker compose start web
```

**Expected** Nagios validates with zero errors and records CRITICAL → OK for the database and HTTP checks.

**Scenario questions**

**1. How can Nagios help the administrator detect a server resource problem before the rental portal becomes unavailable?**<br>Compare CPU, memory, disk and uptime service results before demand causes application failures.<br><br>
**2. When would a service be reported as WARNING rather than CRITICAL?**<br>WARNING marks the first threshold, while CRITICAL marks a higher threshold or an unavailable service.<br><br>
**3. How can an HTTP service check distinguish a web application failure from a complete server failure?**<br>The HTTP check catches a response such as HTTP 500 even when the host is reachable.<br><br>
**4. What monitoring information would be unavailable if the Nagios server itself stopped?**<br>No new measurements, transitions or recovery records are available from that Nagios server.<br><br>
**5. How would you determine whether a failed vehicle availability request is related to Tomcat, MySQL or the network?**<br>Compare the HTTP and MySQL checks, then inspect port mappings or routing if local checks pass.

## Q5 — AWS — Cloud Deployment using EC2

Deploy the assigned app to Ubuntu EC2.

**AWS console** [awsacademy.instructure.com](https://awsacademy.instructure.com/) → **Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved x86 instance, about **16 GiB gp3** if allowed, **public IPv4**, and a `.pem` key pair. Inbound rules are **TCP 22 from My IP** and **TCP 8080 from your or the examiner's IP**.
**PowerShell in Araiza/s6**
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
cd Araiza/s6
```

[deploy.sh](aws/deploy.sh) fetches the Java source, builds the WAR and starts Tomcat on port 8080.
**Ubuntu EC2 terminal, in Araiza/s6**
```bash
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

**Browser** Replace `PUBLIC_IP` in `http://PUBLIC_IP:8080/` with the EC2 address. If it fails, run `sudo journalctl -u araiza-s6-tomcat -n 60 --no-pager` in the Ubuntu SSH window and check the inbound rule.

**Expected** Your application opens at the public address.

**Scenario questions**

**1. Which EC2 or security group configuration issues could prevent customers from opening the rental portal?**<br>Check whether TCP 8080 is open to the test audience and whether the subnet, public IPv4 and local Tomcat listener are correct.<br><br>
**2. Why should the company allow SSH access only from trusted administrative addresses?**<br>Limit access to trusted administrators to reduce exposure to SSH account and protocol attacks.<br><br>
**3. What would customers observe if Tomcat stops while the EC2 instance continues to run?**<br>Customers see refused or timed-out requests until the listener returns.<br><br>
**4. How could the company handle an increase in customer requests during holiday periods?**<br>Scale Tomcat across Availability Zones, using shared durable state and a health-checked load balancer.<br><br>
**5. Why might multiple EC2 instances behind a load balancer be preferred for a customer-facing rental portal?**<br>The load balancer distributes requests and routes around failed instances.

## Troubleshooting and cleanup

- **Port busy** Run `Get-NetTCPConnection -State Listen -LocalPort 8080,8186,8316,8896 -ErrorAction SilentlyContinue`. For a Compose port conflict, change `WEB_PORT` or `NAGIOS_PORT` in your local `.env` and use that port in the browser.
- **Container unhealthy** Run `docker compose logs --tail=40 web db`. For Jenkins errors, check **Console Output** and the names `JDK21` and `Maven3`.

Stop the port-forward with Ctrl+C. The cleanup command keeps your data volumes.
**PowerShell in Araiza/s6**
```powershell
.\scripts\cleanup.ps1 -Kubernetes
```

End the AWS lab and stop or terminate your EC2 instance when done.

### macOS startup

In Terminal, run `open -a Docker` and `brew services start jenkins-lts` if installed via Homebrew. Clone the same branch, use `cd Araiza/s6`, `bash scripts/setup.sh` and `curl`. The Docker, Minikube and kubectl commands are the same.
