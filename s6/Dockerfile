FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY app/upstream/pom.xml .
COPY app/upstream/src ./src
RUN mvn -B -ntp clean test package

FROM tomcat:9.0-jre17-temurin-noble AS runtime
COPY --from=build /build/target/VehicleRentalManagement.war /usr/local/tomcat/webapps/ROOT.war
ARG LAB_REVISION=v1
RUN mkdir /usr/local/tomcat/webapps/revision \
    && printf '%s\n' "$LAB_REVISION" > /usr/local/tomcat/webapps/revision/index.txt
EXPOSE 8080

FROM runtime AS app
