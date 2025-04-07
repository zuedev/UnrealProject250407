#!/bin/bash

# SYNOPSIS
# Checks Docker environment prerequisites and runs Unreal Engine code quality checks inside a container.
#
# DESCRIPTION
# This script performs the following steps:
# 1. Checks if Docker is installed.
# 2. Checks if the Docker daemon is running.
# 3. Pulls or verifies the existence of the required Unreal Engine Docker image.
# 4. If all checks pass, it runs the Unreal Engine Automation Tool (UAT) within the Docker container to perform code quality checks (BuildCookRun).
# 5. Reports success or failure at each step and overall.

# --- Configuration ---
UNREAL_VERSION="5.5.4" # Specify the target Unreal Engine version
DOCKER_IMAGE="ghcr.io/epicgames/unreal-engine:dev-${UNREAL_VERSION}"
PROJECT_NAME="UnrealProject250407" # Set your project name here (without .uproject)

# --- ANSI Color Codes ---
COLOR_RESET='\e[0m'
COLOR_RED='\e[0;31m'
COLOR_GREEN='\e[0;32m'
COLOR_YELLOW='\e[0;33m'
COLOR_CYAN='\e[0;36m'
COLOR_GRAY='\e[0;90m' # Light gray for commands

# --- Helper function for colored output ---
# Usage: cecho <color> "Message" [-n]
cecho() {
    local color="$1"
    local message="$2"
    local no_newline_flag=""
    if [[ "$3" == "-n" ]]; then
        no_newline_flag="-n"
    fi
    # Use -e flag for echo to interpret escape sequences
    echo -e ${no_newline_flag} "${color}${message}${COLOR_RESET}"
}

# --- Script Start ---
clear # Equivalent to Clear-Host

# --- Prerequisites Checks ---

cecho $COLOR_CYAN "Checking prerequisites..."
cecho $COLOR_CYAN "------------------------"

docker_installed=false
docker_running=false
docker_image_exists=false

# 1. Check if Docker is installed
cecho $COLOR_WHITE "1. Is Docker installed? " -n
# Use command -v to check if 'docker' command exists in PATH
# Redirect stdout and stderr to /dev/null to suppress output
if command -v docker > /dev/null 2>&1; then
    docker_installed=true
    cecho $COLOR_GREEN "YES!"
else
    cecho $COLOR_RED "NO!"
    cecho $COLOR_RED "   Please install Docker Engine or Docker Desktop for Linux."
fi

# 2. Check if Docker is running (only if installed)
if $docker_installed; then
    cecho $COLOR_WHITE "2. Is Docker daemon running? " -n
    # Run 'docker info'. If it fails (non-zero exit code), the daemon isn't running.
    # Redirect stdout and stderr to /dev/null
    if docker info > /dev/null 2>&1; then
        docker_running=true
        cecho $COLOR_GREEN "YES!"
    else
        cecho $COLOR_RED "NO!"
        cecho $COLOR_RED "   Please start the Docker service/daemon (e.g., 'sudo systemctl start docker')."
    fi
else
    cecho $COLOR_YELLOW "2. Is Docker daemon running? (Skipped, Docker not installed)"
fi

# 3. Check if the required Docker image exists (only if Docker is running)
if $docker_installed && $docker_running; then
    cecho $COLOR_WHITE "3. Accessing Unreal Engine Docker image? (${DOCKER_IMAGE}) (This may take a while...)"
    # Attempt to pull the image. Docker pull is idempotent; it only downloads if missing or outdated.
    # Capture output in case of failure, but primarily rely on exit code ($?).
    pull_output=$(docker pull "$DOCKER_IMAGE" 2>&1)
    pull_exit_code=$?

    if [ $pull_exit_code -eq 0 ]; then
        docker_image_exists=true
        # Check output for confirmation message (optional, as exit code 0 is usually sufficient)
        if [[ "$pull_output" == *"Status: Downloaded newer image"* || "$pull_output" == *"Status: Image is up to date"* || "$pull_output" == *"Already exists"* ]]; then
             cecho $COLOR_GREEN "   Image is available locally."
        else
            # Even if exit code is 0, maybe show a generic success if specific text not found
            cecho $COLOR_GREEN "   Image pull/check successful."
        fi
    else
        cecho $COLOR_RED "   NO! Failed to pull or find the Docker image."
        cecho $COLOR_RED "   Error (Exit Code: $pull_exit_code):"
        cecho $COLOR_RED "   $pull_output" # Show the output for debugging
    fi
else
    cecho $COLOR_YELLOW "3. Accessing Unreal Engine Docker image? (Skipped, Docker not installed or running)"
fi

cecho $COLOR_CYAN "------------------------"

# --- Execute Main Action ---

if $docker_installed && $docker_running && $docker_image_exists; then
    cecho $COLOR_GREEN "All checks passed. Running code quality checks..."

    # Define the command arguments for clarity
    PROJECT_FILE="/project/${PROJECT_NAME}.uproject"
    ARCHIVE_DIR="/project/Packaged"
    UAT_SCRIPT="/home/ue4/UnrealEngine/Engine/Build/BatchFiles/RunUAT.sh" # Assuming Linux container path

    # Construct the command to run inside the container
    # Note: Ensure proper quoting for the command string passed to bash -c
    COMMAND_IN_CONTAINER="$UAT_SCRIPT BuildCookRun -utf8output -platform=Linux -clientconfig=Shipping -serverconfig=Shipping -project=$PROJECT_FILE -noP4 -nodebuginfo -allmaps -cook -build -stage -prereqs -pak -archive -archivedirectory=$ARCHIVE_DIR"

    cecho $COLOR_WHITE "Executing command in container:"
    # Use $PWD for the current working directory in Bash
    # Use double quotes around the command passed to bash -c
    docker_run_cmd="docker run --rm -v \"${PWD}:/project\" -w /project \"$DOCKER_IMAGE\" /bin/bash -c \"$COMMAND_IN_CONTAINER\""
    cecho $COLOR_GRAY "$docker_run_cmd"

    # Execute the docker command
    # No '&' needed like in PowerShell
    docker run --rm -v "${PWD}:/project" -w /project "$DOCKER_IMAGE" /bin/bash -c "$COMMAND_IN_CONTAINER"

    # Check the exit code of the *last* command executed ($?)
    docker_exit_code=$?
    if [ $docker_exit_code -eq 0 ]; then
        cecho $COLOR_GREEN "------------------------"
        cecho $COLOR_GREEN "Code quality checks completed successfully!"
    else
        cecho $COLOR_RED "------------------------"
        cecho $COLOR_RED "Code quality checks failed! (Exit Code: $docker_exit_code)"
    fi
else
    cecho $COLOR_RED "One or more prerequisite checks failed."
    cecho $COLOR_RED "Please resolve the issues listed above before running the script again."
fi

cecho $COLOR_WHITE "Script finished."

exit 0 # Explicitly exit with success code if script reaches the end without error blocks forcing an exit