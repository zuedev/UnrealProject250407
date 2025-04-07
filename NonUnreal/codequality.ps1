<#
.SYNOPSIS
Checks Docker environment prerequisites and runs Unreal Engine code quality checks inside a container.

.DESCRIPTION
This script performs the following steps:
1. Checks if Docker is installed.
2. Checks if the Docker daemon is running.
3. Pulls or verifies the existence of the required Unreal Engine Docker image.
4. If all checks pass, it runs the Unreal Engine Automation Tool (UAT) within the Docker container to perform code quality checks (BuildCookRun).
5. Reports success or failure at each step and overall.
#>

# Configuration
$unrealVersion = "5.5.4" # Specify the target Unreal Engine version
$dockerImage = "ghcr.io/epicgames/unreal-engine:dev-$unrealVersion"
$projectName = "UnrealProject250407" # Set your project name here (without .uproject)

# --- Script Start ---
Clear-Host

# --- Prerequisites Checks ---

Write-Host "Checking prerequisites..." -ForegroundColor Cyan
Write-Host "------------------------"

# 1. Check if Docker is installed
Write-Host "1. Is Docker installed?" -NoNewline
$dockerInstalled = $false
try {
    # Attempt to find docker.exe in the PATH
    Get-Command docker.exe -ErrorAction Stop | Out-Null
    $dockerInstalled = $true
    Write-Host " YES!" -ForegroundColor Green
}
catch {
    Write-Host " NO!" -ForegroundColor Red
    Write-Host "   Please install Docker Desktop or Docker Engine."
}

# 2. Check if Docker is running (only if installed)
$dockerRunning = $false
if ($dockerInstalled) {
    Write-Host "2. Is Docker daemon running?" -NoNewline
    try {
        # Run 'docker info'. If it fails or returns specific errors, the daemon isn't running properly.
        # Redirect stderr (2) to stdout (1) to capture potential errors in the variable.
        $dockerInfo = docker info 2>&1
        # Check if the command executed without throwing an error that would be caught by 'catch'
        # $? checks if the *last command* succeeded. Docker info might "succeed" but print an error message if daemon is off.
        # A more reliable check is often just letting the command run and catching the exception.
        # If no exception is caught, we assume it's running.
        $dockerRunning = $true
        Write-Host " YES!" -ForegroundColor Green
    }
    catch {
        # Error likely means the daemon is not running or docker command failed.
        Write-Host " NO!" -ForegroundColor Red
        Write-Host "   Please start the Docker service/daemon."
        # Optional: Print the error message from docker info
        # if ($_.Exception.Message) { Write-Warning "Docker Info Error: $($_.Exception.Message)" }
    }
}
else {
    Write-Host "2. Is Docker daemon running? (Skipped, Docker not installed)" -ForegroundColor Yellow
}

# 3. Check if the required Docker image exists (only if Docker is running)
$dockerImageExists = $false
if ($dockerInstalled -and $dockerRunning) {
    Write-Host "3. Accessing Unreal Engine Docker image? ($dockerImage) (This may take a while...)" -NoNewline
    try {
        # Attempt to pull the image. Docker will only download if it's missing or outdated.
        # Redirect stderr (2) to stdout (1) to capture output/errors.
        $pullOutput = docker pull $dockerImage 2>&1

        # Check the output message from docker pull.
        if ($pullOutput -match "Downloaded newer image" -or $pullOutput -match "Image is up to date") {
            $dockerImageExists = $true
            Write-Host " YES!" -ForegroundColor Green
        }
        else {
            # If the output doesn't indicate success, something went wrong (e.g., image not found, auth error)
            Write-Host " NO!" -ForegroundColor Red
            Write-Host "   Failed to pull or find the Docker image."
            Write-Host "   Output: $pullOutput" # Show the output for debugging
        }
    }
    catch {
        # Catch errors during the 'docker pull' execution itself
        Write-Host " NO!" -ForegroundColor Red
        Write-Host "   Error executing 'docker pull': $($_.Exception.Message)"
    }
}
else {
    Write-Host "3. Accessing Unreal Engine Docker image? (Skipped, Docker not installed or running)" -ForegroundColor Yellow
}

Write-Host "------------------------"

# --- Execute Main Action ---

if ($dockerInstalled -and $dockerRunning -and $dockerImageExists) {
    Write-Host "All checks passed. Running code quality checks..." -ForegroundColor Green

    # Define the command arguments for clarity
    $projectFile = "/project/${projectName}.uproject"
    $archiveDir = "/project/Packaged"
    $uatScript = "/home/ue5/UnrealEngine/Engine/Build/BatchFiles/RunUAT.sh"

    # Construct the command to run inside the container
    $commandInContainer = "$uatScript BuildCookRun -utf8output -platform=Linux -clientconfig=Shipping -serverconfig=Shipping -project=$projectFile -noP4 -nodebuginfo -allmaps -cook -build -stage -prereqs -pak -archive -archivedirectory=$archiveDir"

    Write-Host "Executing command in container:"
    Write-Host "docker run --rm -v ${PWD}:/project -w /project $dockerImage /bin/bash -c ""$commandInContainer""" -ForegroundColor Gray

    # Execute the docker command
    # Using '&' is not strictly necessary here but doesn't hurt
    & docker run --rm -v "${PWD}:/project" -w /project $dockerImage /bin/bash -c "$commandInContainer"

    # Check the exit code of the last external command ($LASTEXITCODE)
    if ($LASTEXITCODE -eq 0) {
        Write-Host "------------------------" -ForegroundColor Green
        Write-Host "Code quality checks completed successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "------------------------" -ForegroundColor Red
        Write-Host "Code quality checks failed! (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
    }
}
else {
    Write-Host "One or more prerequisite checks failed." -ForegroundColor Red
    Write-Host "Please resolve the issues listed above before running the script again." -ForegroundColor Red
}

Write-Host "Script finished."