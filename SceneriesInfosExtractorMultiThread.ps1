

function GetRunwayAreaValue #Renvoi un equivalent m2 de l'aeroport
{
    param (
        [string]$length,  #"1234.5M" "1234.58Ft"
        [string]$width
    )
    try {
        $floatLength = 0
        $floatwidth = 0
        $area = 0

        $floatLength = DistanceToMeter $length
        $floatwidth = DistanceToMeter $width

        $area = [int]($floatLength * $floatwidth)
        
        return $area  #En M²
    }
    catch {
        throw $_.Exception.Message
    }
}

function GetAirportSize
{
    param (
        [int]$RunwayArea,  #En M2
        [int]$RunwayMaximumLength
    )
    try {
        if($RunwayArea -ge 220000 -and $RunwayMaximumLength -ge 2900)
        {
            $size = "Large"
        } 
        elseif($RunwayArea -ge 100000 -and $RunwayMaximumLength -ge 2000)
        {
            $size = "Medium"
        } 
        else
        {
            $size = "Small"
        }

        return $size
    }
    catch {
        throw $_.Exception.Message
    }
}

function DistanceToMeter  #Param "1234.45FT" or "1234.14M"
{
    param(
        [string]$distanceString
    )
    try {
        if($distanceString -like "*M")
        {
            $floatDistance = [float]($distanceString -replace "M")
        }
        elseif($distanceString -like "*FT")
        {
            $floatDistance = [float]($distanceString -replace "FT") * 0.3048
        }
        else {
            throw "Not a valid distance"
        }
    }
    catch {
        throw $_.Exception.Message
    }

    return $floatDistance
}

$ImcrementSharedVariable = {

    process {
        Write-Host "Traitement de: $($_.Local)"
        $repScenTmp = $($_.Local).Replace("\","_").replace(":","_")
        $sceneryTemp = "$tempRep\$repScenTmp"

        $bgls = "$($_.Local)\scenery"
        if(!(Test-Path $bgls.Replace("[","``[").Replace("]","``]"))){
            Write-Host "$($bgls) DOES NOT EXISTS"
            return
        }
        $folder = New-Item -ItemType Directory -Path $sceneryTemp
        $xmls = $sceneryTemp.Replace(" ","`` ").Replace("(","``(").Replace(")","``)").Replace("[","``[").Replace("]","``]").Replace(",","``,").Replace("'","``'")
        
        $bglsForDocker = $bgls.Replace(" ","`` ").Replace("(","``(").Replace(")","``)").Replace("[","``[").Replace("]","``]").Replace(",","``,").Replace("'","``'")

        Invoke-Expression "docker run --isolation=process --rm -v $($bglToXmlPath):C:\Bgl2Xml -v $($bglsForDocker):C:\bgls -v $($xmls):C:\xmls -v D:\Documents\Sources\P3D_Scripts\Contrainershit:c:\scripts mcr.microsoft.com/windows/servercore:1909 powershell.exe c:\scripts\BGLToXMLContainerEdition.ps1"

        $xmlFiles = @($folder | Get-ChildItem)

        foreach($xmlFile in $xmlFiles)
        {
            try {
                [xml]$xml = ($xmlFile | Get-Content)
            
                if(($null -ne $xml.FSData.Airport) -and ($null -ne $xml.FSData.Airport.Runway))
                {
                    #$xml.FSData.Airport.Runway
                    $TotalRunwaySurface = 0
                    $MaxRunwayLength = 0

                    foreach($runway in $xml.FSData.Airport.Runway)
                    {
                        $TotalRunwaySurface += GetRunwayAreaValue $runway.length $runway.width
                        $currentRunwayLength = DistanceToMeter $runway.length
                        if($currentRunwayLength -gt $MaxRunwayLength)
                        {
                            $MaxRunwayLength = $currentRunwayLength
                        }
                    }
                    $airportSize = GetAirportSize $TotalRunwaySurface $MaxRunwayLength

                    $airport = @{
                        "OACI" = $($xml.FSData.Airport.ident);
                        "Country" = $($xml.FSData.Airport.country);
                        "City" = $($xml.FSData.Airport.city);
                        "Latitude" = [double]$($xml.FSData.Airport.lat);
                        "Longitude" = [double]$($xml.FSData.Airport.lon);
                        "Altitude" = $($xml.FSData.Airport.alt);
                        "Name" = $($xml.FSData.Airport.name);
                        "State" = $($xml.FSData.Airport.state);
                        "Bgl_Size" = ((Get-Item -Path "$($bgls.Replace("[","``[").Replace("]","``]"))\$($xmlFile.basename).bgl").Length)/1KB;
                        "XML_Size" = ($xmlFile.Length)/1KB;
                        "RunwayArea" = $TotalRunwaySurface;
                        "AirportSize" = $airportSize
                    }
                    $dataAirport.Add($xml.FSData.Airport.ident , $airport)
                }
                else {
                    Remove-Item "$($xmlFile.fullname)" -Force -Confirm:$false
                }       
            }
            catch {
                Write-Host "Exception with file: $($xmlFile.fullname) --> $($PSItem.Exception.Message)" -ForegroundColor Red
            }
        }

        $folder | Remove-Item -Force -Confirm:$false -Recurse
    }
}


Get-Module SplitPipeline

$tempRep = "$PSScriptRoot\Temp"
if (!(Test-Path -Path $tempRep)){New-Item -ItemType Directory -Path $tempRep} 
Get-ChildItem -Path $tempRep | Remove-Item -Force -Confirm:$false -Recurse

$dataAirport = [hashtable]::Synchronized(@{})
$Throttle = 15

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
        if($i -ge 10000){
            break
        }
    }
}

cls

$filteredScenery | Split-Pipeline -Script $ImcrementSharedVariable  -Variable dataAirport,tempRep,bglToXmlPath -Function GetRunwayAreaValue, DistanceToMeter, GetAirportSize -Count $Throttle

Write-Host "!!--BGL STATS--!!"
$dataAirport.Values.Bgl_Size | measure -AllStats
Write-Host "!!--XML STATS--!!"
$dataAirport.Values.XML_Size | measure -AllStats

$jsonfile = ConvertTo-Json -InputObject $dataAirport

$jsonfile | Set-Content -Path "$($tempRep)\airports.json" -Encoding unicode

$kmlTemplate = ".\Map\template.kml" 

$kmlGroups = $dataAirport.Values | Group-Object -Property AirportSize

foreach($group in $kmlGroups)
{
    [xml]$kml = Get-Content $kmlTemplate -Encoding utf8
    
    #$group.Name
    #$group.Group

    foreach($airpot in $group.Group)
    {
        [xml]$kmlPlacemark = "<Placemark>
                <name>$($airpot.OACI) - $($airpot.city) - $($airpot.name)</name>
                <description></description>
                <Point>
                <coordinates>$($airpot.Longitude -replace ",","."),$($airpot.Latitude -replace ",",".")</coordinates>
                </Point>
            </Placemark>" 
       $kml.kml.AppendChild($kml.ImportNode($kmlPlacemark.Placemark,$true)) | Out-Null
    }

    $kml.Save("$($tempRep)\$($group.Name)_Airports.kml")
}

