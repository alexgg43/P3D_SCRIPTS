

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
        elseif($RunwayMaximumLength -ge 1000)
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

function GetOppositeRunway 
{
    param(
        [string]$number,
        [string]$designator
    )
    

    if($designator -like "LEFT")
    {
        $oppositeDesignator = "RIGHT"
    }
    elseif($designator -like "RIGHT")
    {
        $oppositeDesignator = "LEFT"
    }
    elseif($designator -like "CENTER")
    {
        $oppositeDesignator = "CENTER"
    }
    else {
        $oppositeDesignator = "NONE"
    }

    try {
        [int]$number = [convert]::ToInt32($number, 10)

        $oppositeNumber = ($number + 18 )%36
        if($oppositeNumber -eq 0)
        {
                $oppositeNumber = 36
        }

        $oppositeRunway = @{
            "Number" = [string]("{0:d2}" -f [int]$oppositeNumber)
            "Designator" = $oppositeDesignator
        } 
        return $oppositeRunway
    }
    catch {
        $oppositeNumber = $number

        $oppositeRunway = @{
            "Number" = $oppositeNumber
            "Designator" = $oppositeDesignator
        } 
        return $oppositeRunway
    }
}

function isSameAirport
{
    param(
        $airport1,
        $airport2
    )
    if($airport1.OACI -ne $airport2.OACI)
    {
        return $false
    }
    if($airport1.Country -ne $airport2.Country)
    {
        return $false
    }
    if($airport1.City -ne $airport2.City)
    {
        return $false
    }
    if($airport1.State -ne $airport2.State)
    {
        return $false
    }
    if([Math]::Abs($($airport1.Latitude) - $($airport2.Latitude)) -gt 0.1)
    {
        return $false
    }
    if([Math]::Abs($($airport1.Longitude) - $($airport2.Longitude)) -gt 0.1)
    {
        return $false
    }
    return $true
}

$ImcrementSharedVariable = {

    process {
        Write-Host "Traitement de: $($_.Local)"
        $repScenTmp = $($_.Local).Replace("\","_").replace(":","_")
        $sceneryTemp = "$tempRep\$repScenTmp"

        $arrayCountryGroupsScenery = @()

        $bgls = "$($_.Local)\scenery"
        if(!(Test-Path $bgls.Replace("[","``[").Replace("]","``]"))){
            Write-Host "$($bgls) DOES NOT EXISTS"
            return
        }
        $folder = New-Item -ItemType Directory -Path $sceneryTemp
        $xmls = $sceneryTemp.Replace(" ","`` ").Replace("(","``(").Replace(")","``)").Replace("[","``[").Replace("]","``]").Replace(",","``,").Replace("'","``'")
        
        $bglsForDocker = $bgls.Replace(" ","`` ").Replace("(","``(").Replace(")","``)").Replace("[","``[").Replace("]","``]").Replace(",","``,").Replace("'","``'")

        Invoke-Expression "docker run --isolation=process --rm -v $($bglToXmlPath):C:\Bgl2Xml -v $($bglsForDocker):C:\bgls -v $($xmls):C:\xmls -v $currentRep\Contrainershit:c:\scripts mcr.microsoft.com/windows/servercore:1909 powershell.exe c:\scripts\BGLToXMLContainerEdition.ps1"

        $xmlFiles = @($folder | Get-ChildItem)

        foreach($xmlFile in $xmlFiles)
        {
            try {
                [xml]$xml = ($xmlFile | Get-Content)
            
                if(($null -ne $xml.FSData.Airport) -and ($null -ne $xml.FSData.Airport.Runway))
                {
                    if(!($($xml.FSData.Airport.name) -like "*ignore*" -or $($xml.FSData.Airport.city) -like "*ignore*"))
                    {
                        #$xml.FSData.Airport.Runway
                        $TotalRunwaySurface = 0
                        $MaxRunwayLength = 0
                        $arrayRunway = @()

                        foreach($runway in $xml.FSData.Airport.Runway)
                        {
                            $TotalRunwaySurface += GetRunwayAreaValue $runway.length $runway.width
                            $currentRunwayLength = DistanceToMeter $runway.length
                            if($currentRunwayLength -gt $MaxRunwayLength)
                            {
                                $MaxRunwayLength = $currentRunwayLength
                            }

                            $oppositeRunway = GetOppositeRunway $($runway.number) $($runway.designator)

                            $runway =  @{
                                "Number" = $runway.number
                                "Designator" = $runway.designator
                                "NumberOpposite" = $oppositeRunway.Number
                                "DesignatorOpposite" = $oppositeRunway.Designator
                                "Length" = DistanceToMeter $runway.length
                                "Width" = DistanceToMeter $runway.width
                                "Surface" = $runway.surface
                            } 

                            $arrayRunway += $runway
                        }
                        $airportSize = GetAirportSize $TotalRunwaySurface $MaxRunwayLength

                        $airport = @{
                            "OACI" = $($xml.FSData.Airport.ident);
                            "Country" = $($xml.FSData.Airport.country);
                            "City" = $($xml.FSData.Airport.city);
                            "Latitude" = [double]$($xml.FSData.Airport.lat);
                            "Longitude" = [double]$($xml.FSData.Airport.lon);
                            "Altitude" = DistanceToMeter $($xml.FSData.Airport.alt);
                            "Name" = $($xml.FSData.Airport.name);
                            "State" = $($xml.FSData.Airport.state);
                            "Bgl_Size" = ((Get-Item -Path "$($bgls.Replace("[","``[").Replace("]","``]"))\$($xmlFile.basename).bgl").Length)/1KB;
                            "XML_Size" = ($xmlFile.Length)/1KB;
                            "RunwayArea" = $TotalRunwaySurface;
                            "AirportSize" = $airportSize
                            "RunwayList" = $arrayRunway
                            "BGLPath" = (Get-Item -Path "$($bgls.Replace("[","``[").Replace("]","``]"))\$($xmlFile.basename).bgl").FullName
                        }
                        
                        if($dataAirport.ContainsKey($xml.FSData.Airport.ident))
                        {
                            if($(isSameAirport $airport $($dataAirport[$xml.FSData.Airport.ident])) -eq $true)
                            {
                                Write-Host "Exception with file: $($xmlFile.fullname) --> $($xml.FSData.Airport.ident) is same airport" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "Exception with file: $($xmlFile.fullname) --> $($xml.FSData.Airport.ident) Fake same airport " -ForegroundColor Red
                            }
                        }
                        else {
                            $dataAirport.Add($xml.FSData.Airport.ident , $airport)
                        }
                        
                        
                        if($arrayCountryGroupsScenery -notcontains $($xml.FSData.Airport.country))
                        {
                            $arrayCountryGroupsScenery += $($xml.FSData.Airport.country)
                        }
                    }
                    else {
                        Write-Host "Exception with file: $($xmlFile.fullname) - File to ignore" -ForegroundColor Yellow
                        Remove-Item "$($xmlFile.fullname)" -Force -Confirm:$false
                    }
                }
                else {
                    Remove-Item "$($xmlFile.fullname)" -Force -Confirm:$false
                }      
            }
            catch {
                Write-Host "Exception with file: $($xmlFile.fullname) --> $($PSItem.Exception.Message)" -ForegroundColor Red
            }
        }

        $dataCountryGroups.Add($_.Layer,$arrayCountryGroupsScenery)

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

#CurrentRep
$currentRep = $PSScriptRoot

#Contain all datas extracted from bgls
$dataAirport = [hashtable]::Synchronized(@{})

#Contain all country groups for areas
$dataCountryGroups = [hashtable]::Synchronized(@{})

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
        if($i -ge 1000){
            break
        }
    }
}

#For Debug
#$filteredScenery = $filteredScenery | Sort-Object {Get-Random}

###################################################
########## Multithreaded data extraction ##########
###################################################
$filteredScenery | Split-Pipeline -Script $ImcrementSharedVariable  -Variable dataAirport,dataCountryGroups,tempRep,bglToXmlPath, currentRep -Function GetRunwayAreaValue, DistanceToMeter, GetAirportSize, GetOppositeRunway, isSameAirport -Count $Throttle

###################################################
########### Extracted data statistics #############
###################################################
Write-Host "!!--BGL STATS--!!"
$dataAirport.Values.Bgl_Size | measure -AllStats
Write-Host "!!--XML STATS--!!"
$dataAirport.Values.XML_Size | measure -AllStats

###########################################################
############## Export airport data to Json ################
###########################################################
$jsonfile = ConvertTo-Json -InputObject $dataAirport -Depth 5

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
        #Write-Host $($airpot | Select -Property *)
        $arrayRunwayStr = ""
        foreach($runway in $airpot.RunwayList)
        {
            if($runway.length -ge 100)
            {
                $arrayRunwayStr = $arrayRunwayStr+"$($runway.Number)$($($runway.Designator).substring(0,1).replace('N',''))/$($runway.NumberOpposite)$($($runway.DesignatorOpposite).substring(0,1).replace('N','')) - $([math]::round(($runway.length/10))*10) m - $($runway.surface)`n"
            }
        }

        $namexml = [System.Security.SecurityElement]::Escape("$($airpot.OACI) - $($airpot.city) - $($airpot.name) - $([math]::round(($airpot.Altitude/10))*10) m")
        [xml]$kmlPlacemark = "<Placemark>
                <name>$namexml</name>
                <description>$arrayRunwayStr</description>
                <Point>
                <coordinates>$($airpot.Longitude -replace ",","."),$($airpot.Latitude -replace ",",".")</coordinates>
                </Point>
            </Placemark>" 
       $kml.kml.AppendChild($kml.ImportNode($kmlPlacemark.Placemark,$true)) | Out-Null
    }

    $kml.Save("$($tempRep)\$($group.Name)_Airports.kml")
}


##########################################################################
############## Export scenery.cfg.json with country groups ###############
##########################################################################
$sceneryJsonCountryGroups = $sceneryJson

foreach($area in $dataCountryGroups.Keys)
{
    foreach($country in $dataCountryGroups[$area])
    {
        if($sceneryJsonCountryGroups["Area.$area"].Groups -notcontains $country)
        {
            $sceneryJsonCountryGroups["Area.$area"].Groups += $country
        }
    }
}

$jsonfileCountryGroups = ConvertTo-Json -InputObject $sceneryJsonCountryGroups -Depth 8

$jsonfileCountryGroups | Set-Content -Path "$($tempRep)\sceneryCountryGroups.cfg.json" -Encoding unicode

