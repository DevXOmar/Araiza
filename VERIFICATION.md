# Verification

Verified on 19 November 2026 using macOS arm64, Maven 3.9.16, Docker Desktop 29.1.2 and Compose 2.40.3, Minikube v1.37.0 and an isolated Jenkins 2.580.2 controller. PowerShell parsing and the selected runtime checks used PowerShell 7.5.4 on macOS. The original DOCX files are unchanged.

| Set | Pinned clean Maven build and Tomcat image | Compose config, application HTTP and data persistence | Minikube | Nagios | Jenkins | EC2 |
| --- | --- | --- | --- | --- | --- | --- |
| S1 | PASS · `LibraryRegistration.war` | PASS · WordPress install, seat reservation, duplicate rejection, MySQL replacement and two web replicas | PASS · 2 → 5, replacement, update and undo | PASS | PASS · green and deliberate JUnit failure | NOT RUN |
| S2 | PASS · `LibraryRegistration.war` | PASS · PostgreSQL appointment write/read after replacement, two Tomcat replicas | PASS · 2 → 5, replacement, update and undo | PASS | PASS · green and deliberate JUnit failure, PR merge-ref fixture | NOT RUN |
| S3 | PASS · `ORS.war` | PASS · MySQL record and uploaded resume bytes after DB replacement, two web replicas, PowerShell runtime smoke | PASS · 2 → 5, replacement, update and undo | PASS | PASS · release-ref fixture, green and deliberate JUnit failure | NOT RUN |
| S4 | PASS · `OnlineShoppingApp.war` | PASS · WordPress page survived MySQL replacement | PASS · 3 → 5, replacement, update and undo | PASS | PASS · Freestyle WAR archive and expected Surefire failure | NOT RUN |
| S5 | PASS · `GymManagementSystem.war` | PASS · WordPress page survived MySQL replacement | PASS · 2 → 5, replacement, update and undo | PASS | PASS · Freestyle WAR archive and expected Surefire failure | NOT RUN |
| S6 | PASS · `VehicleRentalManagement.war` | PASS · WordPress page survived MySQL replacement | PASS · 2 → 4, replacement, update and undo, missing-image recovery | PASS | PASS · Freestyle WAR archive and expected Surefire failure | NOT RUN |
| S7 | PASS · `sportssystem.war` | PASS · fixtures in PostgreSQL, live Redis counter, two serving Flask replicas and PowerShell runtime smoke | PASS · 2 → 4, replacement, update and undo | PASS | PASS · Scripted Pipeline and WAR archive | NOT RUN |
| S8 | PASS · `bloodbank.war` | PASS · PostgreSQL inventory entry survived replacement | PASS · 2 → 4, replacement, update and undo | PASS | PASS · Scripted Pipeline and WAR archive | NOT RUN |
| S9 | PASS · `apartmentsystem.war` | PASS · PostgreSQL maintenance request survived replacement, Tomcat served on host port 8090 in a separate smoke test | PASS · 4 → 6, replacement, update and undo | PASS | PASS · Pipeline, WAR archive and local Tomcat HTTP deployment | NOT RUN |

## Evidence behind the results

- **Source and build.** Cloned all nine assigned repositories, checked their default branch, POM, JSP routes, tests, existing Dockerfiles and clean WAR names. Each `app/source.properties` records the pinned commit. Ran `mvn -B -ntp clean test package` and the supplied Docker builds. All upstreams have zero test classes. S1–S3 lab suites each ran three JUnit tests on a green build and produced exactly one assertion failure in the controlled red run. S2, S3, S8 and S9 companion WARs were built by Compose.
- **Containers.** Validated both Compose files together with `docker compose -f compose.yaml -f nagios/compose.yaml --profile monitoring config --quiet` for each set. The runtime checks submitted synthetic data, read it back and recreated the database containers while preserving their volumes. The S2 initial bind-mounted initializer failed on Docker Desktop. The final PostgreSQL image copies the initializer into the image and passed with a separate verification volume. The earlier volume was retained. S3 and S7 also passed the supplied `scripts/verify.ps1 -RecreateDatabase` on macOS PowerShell.
- **Minikube.** Ran each `k8s/verify.ps1` in its own namespace. Validated Ready replicas and EndpointSlices, requested the original home and detail pages over a Service port-forward, compared Pod names after deletion and verified revision markers v1, v2 and v1. S6 also retained four Ready Pods with an intentionally missing image and recovered with rollout undo.
- **Nagios.** Validated each live daemon's configuration with `nagios -v`. Verified scheduled HTTP, database TCP, CPU, memory, disk and uptime checks via Nagios status data. Stopping and recreating the DB changed its TCP check from OK to CRITICAL to OK. No outbound notifications were sent.
- **Jenkins.** Ran the scripted jobs on macOS and configured actual Freestyle jobs for S4–S6. Checked WAR archives and the intended red runs. S1–S3 read the lab tests from a local Git fixture with the same source files. S3 exercised a `release` ref from an isolated mirror of the assigned source. S2 also built the PR merge ref in a fixture with a matching PR event supplied as environment variables. S9 deployed the archive to a local Tomcat container and verified HTTP.
- **Files and commands.** Parsed the 45 PowerShell scripts and the PowerShell code blocks in all nine manuals. Parsed local Bash deployment scripts, checked YAML, manifest selectors and expected replica counts, validated repository-relative file references and matched the scenario sections to all 210 paper subquestions. Checked the staged paths for private keys, local environment files, upstream checkouts and build output. Compared the paper directory with the base commit.

## Remaining environment-dependent checks

| Status | Check | Dependency |
| --- | --- | --- |
| NOT RUN | Windows 10/11 runtime, Jenkins Windows service and `bat` execution | macOS was the available host. PowerShell parsing and selected macOS runtime checks were executed. |
| NOT RUN | Live GitHub webhook and branch events, S2's public webhook filter, S9 ngrok, and S3 optional SMTP | Requires a writable upstream fork or training repository, a reachable authenticated controller and the applicable account credentials. |
| NOT RUN | AWS deployment, public IPv4 checks, S2 CloudWatch, S8 User Data and S1 Docker Hub publishing | Requires the student's AWS Academy session and, for S1, their Docker Hub repository. No external cloud resources were provisioned. |
| NOT RUN | NodePort tunnel and S2 optional LoadBalancer and HPA live behavior | Service HTTP was verified through port-forward. HPA and LoadBalancer are documented separately from the manual scaling test. |
