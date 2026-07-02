# Runtime stage (pre-compiled JAR copied from host)
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# Copy the built jar from the host's target directory
COPY target/expensesplit-0.0.1-SNAPSHOT.jar app.jar

# Expose backend port
EXPOSE 8080

# Run Spring Boot app
ENTRYPOINT ["java", "-jar", "app.jar"]
