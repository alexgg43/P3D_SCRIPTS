Install-Module SplitPipeline
cls

$tempRep = "$PSScriptRoot\Temp"
if (!(Test-Path -Path $tempRep)){New-Item -ItemType Directory -Path $tempRep} 
Get-ChildItem -Path $tempRep | Remove-Item -Force -Confirm:$false -Recurse

$dataAirport = [hashtable]::Synchronized(@{})
$Throttle = 6

$pathP3DSceneryDefault = "G:\Prepar3D v4\Scenery"
$excludeListPath = "ExclusionsRegex.csv"
$bglToXmlPath = "H:\Tools\Bgl2Xml186\"

$excludeRegex = $(Get-Content $excludeListPath) -Join "|"

$fileJSon = "$PSScriptRoot\scenery.cfg.json"

$sceneryJson = (Get-Content $fileJSon | ConvertFrom-Json -AsHashtable)

#Move this to array as it is only acceced through a loop

$i = 0
$filteredScenery = [System.Collections.ArrayList]@()
foreach ($hash in $sceneryJson.GetEnumerator())
{
    if(!(($hash.Value.Local -like "$pathP3DSceneryDefault\*") -or ($hash.Value.Title -match $excludeRegex) -or ($hash.Name -like "General")))
    {
        $filteredScenery.Add($hash.value) | Out-Null
        $i++
        if($i -ge 100){
            break
        }
    }
}

$filteredScenery = $filteredScenery | Sort-Object {Get-Random}

$ImcrementSharedVariable = {

    process {
        Write-Host "Traitement de: $($_.Local)"
        $repScenTmp = $($_.Local).Replace("\","_").replace(":","_")
        $sceneryTemp = "$tempRep\$repScenTmp"

        $bgls = "$($_.Local)\scenery"
        if(!(Test-Path $bgls)){
            Write-Host "$($bgls) DOES NOT EXISTS"
            return
        }
        $fol = New-Item -ItemType Directory -Path $sceneryTemp
        $xmls = $sceneryTemp.Replace(" ","`` ").Replace("(","``(").Replace(")","``)").Replace("[","``[").Replace("]","``]").Replace(",","``,")
        
        $bgls = $bgls.Replace(" ","`` ").Replace("(","``(").Replace(")","``)").Replace("[","``[").Replace("]","``]").Replace(",","``,")

        Invoke-Expression "docker run --rm -v $($bglToXmlPath):C:\Bgl2Xml -v $($bgls):C:\bgls -v $($xmls):C:\xmls -v D:\Documents\Sources\P3D_Scripts\Contrainershit:c:\scripts mcr.microsoft.com/dotnet/framework/runtime:4.8 powershell.exe c:\scripts\BGLToXMLContainerEdition.ps1"

        $xmlFiles = @($fol | Get-ChildItem)

        foreach($xmlFile in $xmlFiles)
        {
            [xml]$xml = Get-Content -Path "$($xmlFile.fullname)"
            
            try {
                if($null -ne $xml.FSData.Airport)
                {
                    $airport = @{
                        "Country" = $($xml.FSData.Airport.country) ;
                        "City" = $($xml.FSData.Airport.city);
                        "Latitude" = [double]$($xml.FSData.Airport.lat);
                        "Longitude" = [double]$($xml.FSData.Airport.lon);
                        "Altitude" = $($xml.FSData.Airport.alt);
                        "Name" = $($xml.FSData.Airport.name);
                        "State" = $($xml.FSData.Airport.state)
                    }
                    $dataAirport.Add($xml.FSData.Airport.ident , $airport)
                }
                else {
                    Remove-Item "$($xmlFile.fullname)" -Force -Confirm:$false
                }       
            }
            catch {
                Write-Host "$($xmlFile.basename) - Not a valid airpot file !"
            }
        }

        #$folder | Remove-Item -Force -Confirm:$false -Recurse
    }
}

$filteredScenery | Split-Pipeline -Script $ImcrementSharedVariable  -Variable dataAirport,tempRep,bglToXmlPath -Count $Throttle

$dataAirport | fl

