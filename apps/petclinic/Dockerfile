# syntax=docker/dockerfile:1
# ----------------------------------------------------------------
# Spring Petclinic als JVM-Image (kein Native Image)
# ----------------------------------------------------------------
# Build-Kontext ist der geklonte Petclinic-Quellcode, siehe build-and-import.sh
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY . .
# Formatter/Checkstyle überspringen, Maven-Cache zwischen Builds behalten
RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw -B -q -DskipTests -Dspring-javaformat.skip=true -Dcheckstyle.skip=true package \
 && cp target/spring-petclinic-*.jar /app.jar

# ----------------------------------------------------------------
# Laufzeit-Image
# ----------------------------------------------------------------
FROM eclipse-temurin:21-jre
RUN useradd --system --uid 10001 --no-create-home petclinic
WORKDIR /app
COPY --from=build /app.jar /app/app.jar
USER 10001
EXPOSE 8080
# Heap relativ zum Memory-Limit, Rest bleibt für Metaspace und Java-Agent
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=60", "-jar", "/app/app.jar"]
