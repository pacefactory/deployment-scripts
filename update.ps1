param (
  [string]$ProjectName = "deployment-scripts"
)

Write-Output ""
Write-Output "This will update the Pacefactory SCV2 deployment running on this machine."
Write-Output ""
Write-Output "You will be prompted to enable optional services."
Write-Output "For each prompt, you may enter 'y', 'n', or '?'"
Write-Output "corresponding to yes, no, and help, respectively."
Write-Output "If you are unsure of the importance of given service, select the '?' option."
Write-Output ""
Write-Output ""
Write-Output "The final prompt will ask if you are running in ONLINE or OFFLINE mode."
Write-Output ""
Write-Output "ONLINE mode is to be used for client sites where the autodelete feature"
Write-Output "must be enabled to manage storage constraints."
Write-Output "OFFLINE mode is to be used when running videos using the Offline Processing"
Write-Output "tool. This disabled the autodelete feature, so data persists in the dbserver."

# Init profiles string as empty (no optional profiles)
$profile_str = ""
# Init override string with base docker-compose and override docker-compose file
$override_str="-f docker-compose.yml -f docker-compose.override.yml"
$DEBUG = $TRUE

$env_file = Join-Path -Path $PSScriptRoot -ChildPath ".env"

Write-Output ""
$REPLY = Read-Host "Confirm project name [$ProjectName]"
if ( $REPLY -ne "" ) {
  $ProjectName = $REPLY
}
Write-Output "Project name: '$ProjectName'"

# Enable social profile?
Write-Output ""
Do {
  $REPLY = Read-Host "Enable the social profile? (y/[n]/?) "
  if ( $REPLY -eq "y" ) {
    $profile_str = "$profile_str --profile social"
    Write-Output " -> Will enable social profile"
    break
  }
  elseif ($REPLY -eq "?") {
    Write-Output ""
    Write-Output "The social profile enables the video-based social media web app and video server"
    Write-Output "(social_web_app, social_video_server)"
    # Default option (assumed to be no). Break
  }
  else {
    Write-Output " -> Will NOT enable social profile"
    break
  }
}
While ($TRUE)

# Enable ml profile?
Write-Output ""
Do {
  $REPLY = Read-Host "Enable the machine learning (ml) profile? (y/[n]/?) "
  if ( $REPLY -eq "y" ) {
    $profile_str = "$profile_str --profile ml"
    $override_str = "$override_str -f docker-compose.ml.yml"
    Write-Output " -> Will enable machine learning profile"
    break
  }
  elseif ($REPLY -eq "?") {
    Write-Output ""
    Write-Output "The machine learning profile enables the machine learning service, used"
    Write-Output "to enhance object classifications and detections within the webgui"
    Write-Output "(service_classifier)"
    # Default option (assumed to be no). Break
  }
  else {
    Write-Output " -> Will NOT enable machine learning profile"
    break
  }
}
While ($TRUE)

# Enable rdb profile?
Write-Output ""
Do {
  $REPLY = Read-Host "Enable the relational dbserver profile? (y/[n]/?) "
  if ( $REPLY -eq "y" ) {
    $profile_str = "$profile_str --profile rdb"
    Write-Output " -> Will enable relational dbserver profile"
    break
  }
  elseif ($REPLY -eq "?") {
    Write-Output ""
    Write-Output "The relational dbserver profile enables the relational_dbserver service,"
    Write-Output "which allows integrations between the webgui and a client's existing SQL database"
    Write-Output "(relational_dbserver)"
    # Default option (assumed to be no). Break
  }
  else {
    Write-Output " -> Will NOT enable relational dbserver profile"
    break
  }
}
While ($TRUE)

# Enable proc profile?
Write-Output ""
Do {
  $REPLY = Read-Host "Enable the report processing profile? (y/[n]/?) "
  if ( $REPLY -eq "y" ) {
    $profile_str = "$profile_str --profile proc"
    Write-Output " -> Will enable report processing profile"
    break
  }
  elseif ($REPLY -eq "?") {
    Write-Output ""
    Write-Output "The report processing profile enables the processing of report data for"
    Write-Output "a deployment as a periodic service. This means a user need not view the"
    Write-Output "webgui to have report data processed and stored in the dbserver's uistore"
    Write-Output "(service_processing)"
    # Default option (assumed to be no). Break
  }
  else {
    Write-Output " -> Will NOT enable report processing profile"
    break
  }
}
While ($TRUE)

# Prompt for online/offline mode
Write-Output ""
Write-Output "Which mode (ONLINE or OFFLINE) should be used?"
Write-Output "1 - ONLINE"
Write-Output "2 - OFFLINE"

# This needs to be an infinite loop
While ($TRUE) {
  $REPLY = Read-Host "Select an option (1 or 2): "
  # Online mode: docker-compose.yml and docker-compose.override.yml used by default
  if ($REPLY -eq "1") {
    Write-Output " -> Will run in ONLINE mode"
    break
  }
  elseif ($REPLY -eq "2") {
    Write-Output " -> Will run in OFFLINE mode"
    $override_str = "$override_str -f docker-compose.dev.yml"
    break
  }
  else {
    Write-Output "Please select a valid option (1 or 2)"
  }
}

if ($DEBUG) {
  Write-Output ""
  Write-Output "profile_str: $profile_str"
  Write-Output "override_str: $override_str"
}

Write-Output ""
$REPLY = Read-Host "Pull from DockerHub? ([y]/n)"
if ($REPLY -eq "n") {
  Write-Output " -> Will NOT pull from DockerHub using local images only..."
}
else {
  Write-Output " -> Will pull from DockerHub"
  Write-Output "Log in to DockerHub:"
  docker login
  Write-Output "Login complete; pulling..."
  if (Test-Path -Path $env_file -PathType leaf) {
    $pull_command = "docker compose -p $ProjectName --env-file .env $profile_str $override_str pull" -replace '\s+', ' '
  }
  else {
    Write-Output ".env file not found. Using the .env.example for pull"
    $pull_command = "docker compose -p $ProjectName --env-file .env.example $profile_str $override_str pull" -replace '\s+', ' '
  }
  
  Write-Host "$pull_command"
  Invoke-Expression $pull_command
}

Write-Output ""
Write-Output "Updating deployment..."

if (Test-Path -Path $env_file -PathType leaf) {
  $up_command = "docker compose -p $ProjectName --env-file .env $profile_str $override_str up --detach --remove-orphans" -replace '\s+', ' '
}
else {
  Write-Output ".env file not found. Using the .env.example for launch"
  $up_command = "docker compose -p $ProjectName --env-file .env.example $profile_str $override_str up --detach --remove-orphans" -replace '\s+', ' '
}

Write-Host "$up_command"
Invoke-Expression $up_command

Write-Output ""
$REPLY = Read-Host "Logout from DockerHub? ([y]/n)"
if ($REPLY -eq "n") {
  Write-Output " -> Will NOT logout from DockerHub"
}
else {
  Write-Output " -> Logging out from DockerHub"
  docker logout
}

Write-Output ""
Write-Output "Deployment complete any errors will be noted above."
Write-Output "To check the status of your deployment, run"
Write-Output "'docker ps -a'"
Write-Output ""
