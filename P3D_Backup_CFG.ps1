#!! Change Drive Letter upon you system !!
$driverLetter = "S"

#Other usefull vars
$backupRootFolder = "P3D_CFG_Backups"
$appData_Roaming_Backups_Folder = "AppData_Roaming_Backups"
$appData_Roaming_Folder = "$env:USERPROFILE\AppData\Roaming\Lockheed Martin\Prepar3D v4\"
$programData_Backups_Folder = "ProgramData_Backups"
$programData_Folder = "C:\ProgramData\Lockheed Martin\Prepar3D v4"
$timestamped_Folder_Name = (Get-Date).tostring("dd-MM-yyyy-HH-mm-ss")

#Check source Paths And Dest Drive
$test = Test-Path "$($driverLetter):\"
if ($test.Equals($false)){exit}
$test = Test-Path $appData_Roaming_Folder
if ($test.Equals($false)){exit}
$test = Test-Path $programData_Folder
if ($test.Equals($false)){exit}

#Create mandatory folders if missing
New-Item -Name "$($backupRootFolder)\$($appData_Roaming_Backups_Folder)\$($timestamped_Folder_Name)" -Path "$($driverLetter):\" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
New-Item -Name "$($backupRootFolder)\$($programData_Backups_Folder)\$($timestamped_Folder_Name)" -Path "$($driverLetter):\" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

#Backup Items
Copy-Item -Path "$($appData_Roaming_Folder)\*" -Destination "$($driverLetter):\$($backupRootFolder)\$($appData_Roaming_Backups_Folder)\$($timestamped_Folder_Name)\" -Recurse
Copy-Item -Path "$($programData_Folder)\*" -Destination "$($driverLetter):\$($backupRootFolder)\$($programData_Backups_Folder)\$($timestamped_Folder_Name)\" -Recurse

Write-Host "Backups Done !!"
Pause