

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
        elseif($RunwayMaximumLength -ge 250)
        {
            $size = "Small"
        }
        elseif($RunwayMaximumLength -ge 100)
        {
            $size = "Very Small"
        }
        else
        {
            $size = "Special"
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

        Invoke-Expression "docker run --isolation=process --rm -v $($bglToXmlPath):C:\Bgl2Xml -v $($bglsForDocker):C:\bgls -v $($xmls):C:\xmls -v C:\Users\Kevin\Desktop\devp3d\P3D_SCRIPTS\Contrainershit:c:\scripts mcr.microsoft.com/windows/servercore:1909 powershell.exe c:\scripts\BGLToXMLContainerEdition.ps1"

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
###################################################################
############## SceneriesInfoExtractorMultithread.ps1 ##############
### Extract data for your addons aiports in your P3D sceneries ###
###################################################################

cls

#########################
### Libraries Imports ###
#########################
Get-Module SplitPipeline

#########################
## Temp working folder ##
#########################

$tempRep = "$PSScriptRoot\Temp"
if (!(Test-Path -Path $tempRep))
{
    New-Item -ItemType Directory -Path $tempRep
}
else {
    Get-ChildItem -Path $tempRep | Remove-Item -Force -Confirm:$false -Recurse
} 

############################
### Script Configuration ###
############################

#Contain all datas extracted from bgls
$dataAirport = [hashtable]::Synchronized(@{})

#Limit the number of thread
$Throttle = 15

#Path to the P3D default sceneries
$pathP3DSceneryDefault = "F:\Prepar3D v4\Scenery"

#Regex to set the Scenery name to exclude
$excludeListPath = "ExclusionsRegex.csv"

#Path where the software Gbl2Xml is located
$bglToXmlPath = "C:\Users\Kevin\Desktop\dev\Bgl2Xml186\"

#Load and merge all exclusions regexs
$excludeRegex = $(Get-Content $excludeListPath) -Join "|"

#Path of the json export of your Prepar3d Sceneries, the content of this file must match the real content of your P3D
$fileJSon = "$PSScriptRoot\scenery.cfg.json"

$sceneryJson = (Get-Content $fileJSon | ConvertFrom-Json -AsHashtable)

#TODO sceneryJson : Move this to array as it is only acceced through a loop

###################################################
### Data filtering to remove unwanted sceneries ###
###################################################

$i = 0
$filteredScenery = [System.Collections.ArrayList]@()
foreach ($hash in $sceneryJson.GetEnumerator())
{
    if(!(($hash.Value.Local -like "$pathP3DSceneryDefault\*") -or ($hash.Value.Title -match $excludeRegex) -or ($hash.Name -like "General")))
    {
        $filteredScenery.Add($hash.value) | Out-Null
        $i++
        if($i -ge 100000){
            break
        }
    }
}

#For Debug
#$filteredScenery = $filteredScenery | Sort-Object {Get-Random}

###################################################
########## Multithreaded data extraction ##########
###################################################
$filteredScenery | Split-Pipeline -Script $ImcrementSharedVariable  -Variable dataAirport,tempRep,bglToXmlPath -Function GetRunwayAreaValue, DistanceToMeter, GetAirportSize -Count $Throttle

###################################################
########### Extracted data statistics #############
###################################################
Write-Host "!!--BGL STATS--!!"
$dataAirport.Values.Bgl_Size | measure -AllStats
Write-Host "!!--XML STATS--!!"
$dataAirport.Values.XML_Size | measure -AllStats

###################################################
############## Export data to Json ################
###################################################
$jsonfile = ConvertTo-Json -InputObject $dataAirport

$jsonfile | Set-Content -Path "$($tempRep)\airports.json" -Encoding unicode

###################################################
########### KML export by airport size ############
###################################################
$kmlTemplate = "$PSScriptRoot\Map\template.kml" 

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

