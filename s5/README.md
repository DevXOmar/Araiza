# SET-5 — Gym Membership Management System

## Before starting

**Assigned source** [nikithamoturi/GymManagementSystem](https://github.com/nikithamoturi/GymManagementSystem), branch `main`.

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
cd Araiza\s5
Set-ExecutionPolicy -Scope Process Bypass -Force
```

Keep this PowerShell open for the local steps.

| Open | URL |
| --- | --- |
| Jenkins | `http://localhost:8080/` |
| Compose app | `http://127.0.0.1:8185/` |
| Minikube port-forward | `http://127.0.0.1:8315/` |
| Nagios | `http://127.0.0.1:8895/nagios/` |
| EC2 app | `http://PUBLIC_IP:8080/` |

## Q1 — Docker — Multi-Container Application

Run a standalone WordPress and MySQL site for gym information. [compose.yaml](compose.yaml) sets up `s5-data-net`, matching credentials and `s5-db-data`.
**PowerShell in Araiza/s5**
```powershell
.\scripts\setup.ps1 -EnvOnly
docker compose pull
docker compose up -d --wait --wait-timeout 180
docker compose ps
docker compose logs --tail=10 web db
```

**Browser** Open [http://127.0.0.1:8185/wp-admin/install.php](http://127.0.0.1:8185/wp-admin/install.php). Install WordPress with site title **Gym Information**, choose an admin username, password and email, and sign in. In **Pages → Add New**, create **Membership and Timings**. Add **Morning training starts at 6 AM** and publish.

Run the first line and refresh to see the outage. Run the last two lines and refresh again.
**PowerShell in Araiza/s5**
```powershell
docker compose kill db
docker compose rm -f db
docker compose up -d --wait --wait-timeout 180 db
```

**Expected** Compose shows the renewed DB as healthy, and your published page still displays its sample content.

**Scenario questions**

**1. What would happen to the WordPress portal if the MySQL container stops unexpectedly?**<br>Visitors may see a database connection error when WordPress cannot read its pages from MySQL.<br><br>
**2. How does a named volume help preserve website content when the MySQL container is removed and recreated?**<br>The volume keeps MySQL files beyond container lifetime and Compose reattaches it by name.<br><br>
**3. Why must the WordPress and MySQL containers be connected to the same Docker network?**<br>The shared network gives WordPress the DNS name `db` and access to the MySQL listener.<br><br>
**4. Why is it safer to avoid exposing the MySQL port directly to the public internet?**<br>Leaving the port unpublished limits database access to attached containers.<br><br>
**5. What would you check if WordPress displays an “Error establishing a database connection” message?**<br>Check `docker compose ps`, `docker compose logs web db`, DNS and the database name, user and password used at first initialization.

## Q2 — Jenkins — Java Web Application Build and Continuous Integration

Build the assigned Java project and archive `GymManagementSystem.war`.

**Jenkins GUI** At [localhost:8080](http://localhost:8080/), install **Git and Maven Integration** under **Manage Jenkins → Plugins**. Under **Tools**, set **JDK21** and **Maven3** to your JDK and Maven installation folders, one level above `bin`.

1. **New Item → s5-freestyle → Freestyle project → OK**.
2. In **Configure → Source Code Management → Git**, use `https://github.com/nikithamoturi/GymManagementSystem.git`, no credentials, and branch `*/main`.
3. Under **Build Triggers → Poll SCM**, enter `H/5 * * * *`.
4. Under **Build Steps → Invoke top-level Maven targets**, choose **Maven3** and enter `clean test package`. Under **Post-build Actions → Archive the artifacts**, enter `target/GymManagementSystem.war`.
5. **Save → Build Now**. Open the run's **Console Output** and **Artifacts**.
6. For a red run add `-Dtest=MissingLabTest -Dsurefire.failIfNoSpecifiedTests=true` to the goals, save and build. Restore `clean test package` and build again.

**Expected** The failed run reports no matching test; the successful run archives `GymManagementSystem.war`. The upstream has no test classes.

**Scenario questions**

**1. How can Jenkins help the team identify a compilation error introduced while updating a membership feature?**<br>Console Output shows the compiler error, file and line for the checked-out commit.<br><br>
**2. What happens to the Jenkins build result when compilation succeeds but a test case fails?**<br>A failed test returns a nonzero Maven exit code and prevents a new successful WAR archive.<br><br>
**3. Why is Maven dependency management useful when multiple developers work on the same project?**<br>All developers and agents resolve the same dependency versions from the POM and repositories.<br><br>
**4. How can Jenkins be configured to build only a selected branch of the Gym repository?**<br>Set the Git Branch Specifier to the exact branch, such as `*/feature/membership`, on a repository containing that branch.<br><br>
**5. How does Continuous Integration differ from Continuous Deployment in this project?**<br>CI builds and tests the revision; Continuous Deployment releases a green artifact automatically.

## Q3 — Kubernetes — Container Deployment and Auto Scaling

Deploy the Java app with [deployment.yaml](k8s/deployment.yaml) and [service.yaml](k8s/service.yaml), then scale from 2 to 5 replicas.
**PowerShell in Araiza/s5**
```powershell
.\scripts\setup.ps1
minikube start --driver=docker
minikube image load araiza-s5:v1
```
**PowerShell in Araiza/s5**
```powershell
$ns = 'araiza-s5'
kubectl --context minikube apply -f k8s\namespace.yaml
kubectl --context minikube -n $ns apply -f k8s\deployment.yaml -f k8s\service.yaml
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get 'deploy,pods,svc'
```

Leave this port-forward to the NodePort Service running and open [the app](http://127.0.0.1:8315/).
**Second PowerShell, any folder**
```powershell
kubectl --context minikube -n araiza-s5 port-forward svc/araiza-s5 8315:8080
```

Back in the first window, scale and delete one Pod. Compare its name with the names after recovery.
**PowerShell in Araiza/s5**
```powershell
kubectl --context minikube -n $ns scale deployment/$ns --replicas=5
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
$pod = kubectl --context minikube -n $ns get pods -l "app=$ns" -o 'jsonpath={.items[0].metadata.name}'
kubectl --context minikube -n $ns delete pod $pod
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get pods
```

Update to v2, then undo the update. Relaunch the port-forward if its Pod was replaced.
**PowerShell in Araiza/s5**
```powershell
docker build --target app --build-arg LAB_REVISION=v2 -t araiza-s5:v2 .
minikube image load araiza-s5:v2
kubectl --context minikube -n $ns set image deployment/$ns web=araiza-s5:v2
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get deployment $ns -o wide
kubectl --context minikube -n $ns rollout undo deployment/$ns
kubectl --context minikube -n $ns rollout status deployment/$ns --timeout=240s
kubectl --context minikube -n $ns get deployment $ns -o wide
```

**Expected** The Java app opens and 5 Pods become Ready with a new Pod name after deletion.

**Scenario questions**

**1. What happens to the Gym Membership Portal when one of its application pods crashes?**<br>The Service sends new requests to Ready Pods while Kubernetes restarts or replaces the failed replica.<br><br>
**2. How does Kubernetes ensure that the required number of replicas continues to run?**<br>The ReplicaSet reconciles the number of live Pods with the Deployment's desired count.<br><br>
**3. Why might the organization increase the number of replicas during the membership renewal period?**<br>More replicas can handle peak renewal requests if node and database capacity allow.<br><br>
**4. What role does a Kubernetes Service play when the application is running in multiple pods?**<br>The Service provides a stable endpoint and distributes traffic to Ready replicas.<br><br>
**5. How can the administrator restore the previous application version after an unsuccessful update?**<br>Run `kubectl --context minikube -n araiza-s5 rollout undo deployment/araiza-s5` and watch rollout status.

## Q4 — Nagios — Infrastructure and Application Monitoring

Start Nagios with the checks supplied in [lab.cfg](nagios/lab.cfg). Keep the Compose app from Q1 available.
**PowerShell in Araiza/s5**
```powershell
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring up -d --build --wait --wait-timeout 180
docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring exec -T nagios /opt/nagios/bin/nagios -v /opt/nagios/etc/nagios.cfg
(Get-Content .env | Select-String '^NAGIOS_PASSWORD=').Line.Split('=', 2)[1]
```

**Browser** Open [Nagios](http://127.0.0.1:8895/nagios/) as `nagiosadmin` with the password above. Under **Services**, show **Portal HTTP**, **Database TCP**, CPU, memory, disk and uptime. WARNING / CRITICAL are 75% / 90% for CPU and memory, 80% / 95% disk, under 120s / 30s uptime, and 1s / 3s HTTP response time.

Run these lines individually. After each stop wait for CRITICAL (about a minute), then run its start and show recovery in **Alert History**.
**PowerShell in Araiza/s5**
```powershell
docker compose stop db
docker compose start db
docker compose stop web
docker compose start web
```

**Expected** Nagios validates with zero errors and records CRITICAL → OK for the database and HTTP checks.

**Scenario questions**

**1. How can Nagios help identify unusually high CPU utilization on the Gym application server?**<br>The metrics agent measures Linux CPU utilization and the Nagios thresholds flag activity at 75% and 90%.<br><br>
**2. What is the difference between WARNING and CRITICAL states in Nagios?**<br>WARNING is an early resource threshold, while CRITICAL indicates severe pressure or service failure.<br><br>
**3. How can Nagios detect that the Gym portal is unavailable even when the server itself is running?**<br>The HTTP status and response time are checked separately from host reachability.<br><br>
**4. What is the impact if the Nagios monitoring container stops while the application continues to run?**<br>Nagios cannot run checks, send alerts or record recovery while its container is stopped.<br><br>
**5. How would you identify whether a reported failure is caused by Tomcat, MySQL or network connectivity?**<br>Compare Tomcat HTTP, WordPress HTTP and MySQL TCP, then check `db` resolution and the host listener.

## Q5 — AWS — Cloud Deployment using EC2

Deploy the assigned app to Ubuntu EC2.

**AWS console** [awsacademy.instructure.com](https://awsacademy.instructure.com/) → **Courses → Lab → Module → Launch AWS → Start Lab → AWS → EC2 → Launch Instance**. Choose **Ubuntu Server 24.04 LTS x86_64**, a lab-approved x86 instance, about **16 GiB gp3** if allowed, **public IPv4**, and a `.pem` key pair. Inbound rules are **TCP 22 from My IP** and **TCP 8080 from your or the examiner's IP**.
**PowerShell in Araiza/s5**
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
cd Araiza/s5
```

[deploy.sh](aws/deploy.sh) fetches the Java source, builds the WAR and starts Tomcat on port 8080.
**Ubuntu EC2 terminal, in Araiza/s5**
```bash
bash aws/deploy.sh
curl -fsS http://127.0.0.1:8080/
```

**Browser** Replace `PUBLIC_IP` in `http://PUBLIC_IP:8080/` with the EC2 address. If it fails, run `sudo journalctl -u araiza-s5-tomcat -n 60 --no-pager` in the Ubuntu SSH window and check the inbound rule.

**Expected** Your application opens at the public address.

**Scenario questions**

**1. What could cause the Gym Membership Portal to remain inaccessible through a browser even when the EC2 instance is running?**<br>Check the public IP and routing, TCP 8080 from your source, the host firewall, deployment logs and a local curl.<br><br>
**2. Why should SSH access to the EC2 instance be restricted to authorized IP addresses?**<br>Allow SSH only from authorized addresses to limit attempts against the administrative listener.<br><br>
**3. What happens to the Gym portal if the Tomcat service stops while the EC2 instance remains active?**<br>The portal stops responding even though the EC2 instance still reports running.<br><br>
**4. How can the organization improve the availability of the application during peak membership renewal periods?**<br>Add health-checked replicas, scale for peaks and keep shared data durable.<br><br>
**5. Why would an Application Load Balancer with multiple EC2 instances provide better availability than a single EC2 instance?**<br>An ALB directs requests to healthy instances and keeps service available during one instance's failure or restart.

## Troubleshooting and cleanup

- **Port busy** Run `Get-NetTCPConnection -State Listen -LocalPort 8080,8185,8315,8895 -ErrorAction SilentlyContinue`. For a Compose port conflict, change `WEB_PORT` or `NAGIOS_PORT` in your local `.env` and use that port in the browser.
- **Container unhealthy** Run `docker compose logs --tail=40 web db`. For Jenkins errors, check **Console Output** and the names `JDK21` and `Maven3`.

Stop the port-forward with Ctrl+C. The cleanup command keeps your data volumes.
**PowerShell in Araiza/s5**
```powershell
.\scripts\cleanup.ps1 -Kubernetes
```

End the AWS lab and stop or terminate your EC2 instance when done.

### macOS startup

In Terminal, run `open -a Docker` and `brew services start jenkins-lts` if installed via Homebrew. Clone the same branch, use `cd Araiza/s5`, `bash scripts/setup.sh` and `curl`. The Docker, Minikube and kubectl commands are the same.
