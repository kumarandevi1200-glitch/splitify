# Check if Java is available
$javaVersion = java -version 2>&1
if ($null -eq $javaVersion) {
    Write-Error "Java is not installed or not in PATH. Please install Java 21 to build locally."
    exit 1
}

# 1. Download Maven if not already present
$mavenBin = "maven-dist\apache-maven-3.9.6\bin\mvn.cmd"
if (-not (Test-Path $mavenBin)) {
    Write-Host "Downloading portable Maven to package application locally..."
    $ProgressPreference = 'SilentlyContinue'
    New-Item -ItemType Directory -Force -Path "maven-dist" | Out-Null
    Invoke-WebRequest -Uri "https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.zip" -OutFile "maven.zip"
    Expand-Archive -Path "maven.zip" -DestinationPath "maven-dist"
    Remove-Item "maven.zip"
}

# 2. Package the jar locally
Write-Host "Compiling and packaging jar locally..."
& $mavenBin -f backend/pom.xml clean package -DskipTests

if ($LASTEXITCODE -ne 0) {
    Write-Error "Local Maven compilation failed."
    exit 1
}

# 3. Build and launch Docker containers
Write-Host "Launching Docker Compose..."
docker compose up --build
