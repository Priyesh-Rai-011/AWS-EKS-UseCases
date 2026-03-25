# ── Stage 1: Build ────────────────────────────────────────────────
FROM maven:3.9.6-eclipse-temurin-17 AS builder

WORKDIR /app

# Copy pom first (layer cache — only re-downloads deps if pom changes)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source and build
COPY src ./src
RUN mvn clean package -DskipTests -B

# ── Stage 2: Run ─────────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Copy only the fat JAR from builder stage
COPY --from=builder /app/target/s3oidc-1.0-SNAPSHOT.jar app.jar

# Port
EXPOSE 8080

# Run
ENTRYPOINT ["java", "-jar", "app.jar"]