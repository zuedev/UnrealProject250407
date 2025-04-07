$unrealVersion = "5.5.4"

Clear-Host

Write-Host "Is docker installed?"
$dockerInstalled = $false
try {
    Get-Command docker.exe -ErrorAction Stop | Out-Null
    $dockerInstalled = $true
    Write-Host "YES!" -ForegroundColor Green
}
catch {
    Write-Host "NO!" -ForegroundColor Red
}

Write-Host "Is docker running?"
$dockerRunning = $false
try {
    $dockerInfo = docker info 2>&1
    if ($dockerInfo) {
        $dockerRunning = $true
        Write-Host "YES!" -ForegroundColor Green
    }
}
catch {
    Write-Host "NO!" -ForegroundColor Red
}

Write-Host "Do we have access to the Unreal Engine docker image? (this may take a while)"
$dockerImage = "ghcr.io/epicgames/unreal-engine:dev-$unrealVersion"
$dockerImageExists = $false
try {
    $dockerImageInfo = docker pull $dockerImage 2>&1
    if ($dockerImageInfo -match "Downloaded newer image" -or $dockerImageInfo -match "Image is up to date") {
        $dockerImageExists = $true
        Write-Host "YES!" -ForegroundColor Green
    }
    else {
        Write-Host "NO!" -ForegroundColor Red
    }
}
catch {
    Write-Host "NO!" -ForegroundColor Red
}

if ($dockerInstalled -and $dockerRunning -and $dockerImageExists) {
    Write-Host "All checks passed. Running code quality checks..." -ForegroundColor Green
    $codeQualityCheck = & docker run --rm -v ${PWD}:/project -w /project $dockerImage /bin/bash -c "/home/ue5/UnrealEngine/Engine/Build/BatchFiles/RunUAT.sh BuildCookRun -utf8output -platform=Linux -clientconfig=Shipping -serverconfig=Shipping -project=/project/UnrealProject250407.uproject -noP4 -nodebuginfo -allmaps -cook -build -stage -prereqs -pak -archive -archivedirectory=/project/Packaged"
    if ($codeQualityCheck) {
        Write-Host "Code quality checks passed!" -ForegroundColor Green
    }
    else {
        Write-Host "Code quality checks failed!" -ForegroundColor Red
    }
}
else {
    Write-Host "One or more checks failed. Please resolve the issues before running the docker container." -ForegroundColor Red
}