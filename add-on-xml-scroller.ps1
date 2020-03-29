function ValidateFolderContainsValidAddOnXml {
    param (
        [string]$folderTarget
    )
    try{
        Get-Item -Path $folderTarget | Out-Null
    }
    Catch{
        throw "Folder: $($folderTarget) missing !!"
        return $false
    }
    return $true
}

$documentPath = [Environment]::GetFolderPath("MyDocuments")
$p3dv4AddonDocumentFolder = "$documentPath\Prepar3D v4 Add-ons"
try{
    $p3dv4AddonDocumentFolder = Get-Item -Path $p3dv4AddonDocumentFolder
}
Catch{
    Write-Host -ForegroundColor Red "Folder: $p3dv4AddonDocumentFolder missing !!"
    exit 1
}


#$folders = Get-ChildItem -Path $p3dv4AddonDocumentFolder -Recurse -Directory -Force -ErrorAction SilentlyContinue | Select-Object FullName

try{
    $folders = Get-ChildItem -Path $p3dv4AddonDocumentFolder -Directory -FollowSymlink
}
Catch{
    Write-Host -ForegroundColor Red "Isue with $p3dv4AddonDocumentFolder children!!"
    exit 1
}

#$folders | fl
foreach ($folderTarget in $folders) {
    Write-Host $folderTarget
    Get-Item -Path $folderTarget
    #ValidateFolderContainsValidAddOnXml $folderTarget
}