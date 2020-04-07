$coreP3DPath = "G:\Prepar3D v4"
$excludeListPath = "ExclusionsRegex.csv"
#Réperoire qui doit contenir le dossier contenant les logs des suppression des fichiers du P3D Core
$removedFilesLogBaseDir = [Environment]::GetFolderPath("MyDocuments")
#Dossier contenant les logs des suppression des fichiers du P3D Core
$removedFilesLogDir = "P3DRemovedFilesLogs"

$check = Test-Path -Path "$($removedFilesLogBaseDir)\$($removedFilesLogDir)"
if (!$check){
    New-Item -Name "$removedFilesLogDir" -Path "$removedFilesLogBaseDir" -ItemType Directory | Out-Null
}

$excludeRegex = $(Get-Content $excludeListPath) -Join "|"

function Find-Folders {
    [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $browse = New-Object System.Windows.Forms.FolderBrowserDialog
    $browse.ShowNewFolderButton = $false

    $loop = $true
    while($loop)
    {
        if ($browse.ShowDialog() -eq "OK")
        {
        $loop = $false
		
		#Insert your script here
		
        } else
        {
            $res = [System.Windows.Forms.MessageBox]::Show("You clicked Cancel. Would you like to try again or exit?", "Select a location", [System.Windows.Forms.MessageBoxButtons]::RetryCancel)
            if($res -eq "Cancel")
            {
                #Ends script
                return
            }
        }
    }
    $browse.Dispose()
    return $browse.SelectedPath
}

$externalizedComponentPath = Find-Folders

if (!$externalizedComponentPath){
    exit 0
}

$externalizedItems = Get-ChildItem -Path $externalizedComponentPath -Recurse -Attributes !D

$list = [System.Collections.ArrayList]@()

$timestamped_Name = (Get-Date).tostring("dd-MM-yyyy-HH-mm-ss")
foreach ($item in $externalizedItems) {
    $originalItemPath = $coreP3DPath+$item.FullName.Replace($externalizedComponentPath,"")
    if (Test-Path $originalItemPath){
        #Check if file id contained in target folder
        if ($originalItemPath.Split("\")[2] -match $excludeRegex){
            $infos = @{
                OriginalFile = $originalItemPath
                ExternalFile = $item.FullName
            }
            $list  += New-Object PSObject -Property $infos
            Remove-Item $originalItemPath -Force -Confirm:$false
        }
    }
}

$list | Export-Csv -Path "$($removedFilesLogBaseDir)\$($removedFilesLogDir)\$timestamped_Name.csv" -NoTypeInformation -Delimiter ";"