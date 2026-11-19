# Software Engineering Lab

Nine Windows-first execution guides for the KMIT Software Engineering Lab Internal II. The [original question papers](19-11-26/) and [verification results](VERIFICATION.md) are included.

| Set | Java project and WAR | Local data exercise | Jenkins | Minikube replicas | EC2 host port |
| --- | --- | --- | --- | --- | --- |
| [S1 E-Ticketing](s1/README.md) | E-Ticketing · `LibraryRegistration.war` | WordPress seat booking and MySQL | Pipeline | 2 → 5 | 80 |
| [S2 Hospital](s2/README.md) | HMS · `LibraryRegistration.war` | Appointment companion and PostgreSQL | Pipeline and main-target PR job | 2 → 5 | 8080 |
| [S3 Recruitment](s3/README.md) | ORS · `ORS.war` | Application and resume companion with MySQL | Release-branch Pipeline | 2 → 5 | 8080 |
| [S4 Shopping](s4/README.md) | Online Shopping · `OnlineShoppingApp.war` | Standalone WordPress product portal | Freestyle | 3 → 5 | 8080 |
| [S5 Gym](s5/README.md) | Gym Management · `GymManagementSystem.war` | Standalone WordPress gym portal | Freestyle | 2 → 5 | 8080 |
| [S6 Vehicle Rental](s6/README.md) | Vehicle Rental · `VehicleRentalManagement.war` | Standalone WordPress rental portal | Freestyle | 2 → 4 | 8080 |
| [S7 Sports](s7/README.md) | Sports · `sportssystem.war` | Flask, PostgreSQL and Redis | Scripted Pipeline | 2 → 4 | 8080 |
| [S8 Blood Bank](s8/README.md) | Blood Bank · `bloodbank.war` | Inventory companion and PostgreSQL | Scripted Pipeline | 2 → 4 | 80 static, 8080 WAR |
| [S9 Apartment](s9/README.md) | Apartment · `apartmentsystem.war` | Maintenance companion and PostgreSQL 15 | Pipeline and ngrok webhook | 4 → 6 | 8090 |

## Tools and execution

- Install [Git](https://git-scm.com/downloads), [JDK 21](https://adoptium.net/temurin/releases/?version=21), [Maven](https://maven.apache.org/download.cgi) and [Jenkins LTS](https://www.jenkins.io/download/).
- Use [Docker Desktop](https://www.docker.com/products/docker-desktop/) with Linux containers, [Minikube](https://minikube.sigs.k8s.io/docs/start/) and [kubectl](https://kubernetes.io/docs/tasks/tools/). Docker Desktop includes Compose v2.
- Use the Windows OpenSSH client for [AWS Academy](https://awsacademy.instructure.com/). S9 uses [ngrok](https://ngrok.com/download) for the GitHub push exercise.

Clone Araiza and open the assigned set. Use the set's startup steps, then work through its questions in the order on the paper. Modern Compose uses `compose.yaml`. The local Tomcat images build from a pinned checkout of each assigned repository. Jenkins uses the configured live source branch to demonstrate CI. The standalone WordPress and labeled database companions supply the practical features described in their respective guides.

Run commands from the set directory. Use each set's `scripts/setup.ps1` to fetch source and generate local credentials. Keep the generated `.env` with its database volume. After a practical, use the set cleanup script to retain persistent data. Capture the HTTP response, archived WAR, Ready endpoints and before/after data evidence while the services are still running.
