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

cls

$tempRep = "$PSScriptRoot\Temp"
Remove-Item "$tempRep\*" -Force -Confirm:$false -Recurse

$kmlTemplate = "template.kml"

$dataAirport = @{}

$pathP3DSceneryDefault = "F:\Prepar3D v4\Scenery"
$excludeListPath = "ExclusionsRegex.csv"

$excludeRegex = $(Get-Content $excludeListPath) -Join "|"

$fileJSon = "$PSScriptRoot\scenery.cfg.json"

$sceneryJson = (Get-Content $fileJSon | ConvertFrom-Json -AsHashtable)

$filteredScenery = @{}
$i = 0
foreach ($hash in $sceneryJson.GetEnumerator())
{
    if(!(($hash.Value.Local -like "$pathP3DSceneryDefault\*") -or ($hash.Value.Title -match $excludeRegex) -or ($hash.Name -like "General")))
    {
        #if($hash.Value.Title -like "*LFRB*")
        #{
            $filteredScenery.Add($hash.Name , $hash.value)
            $i++
            if($i -gt 10000)
            {
                break
            }
        #{
        
    }
}


foreach($scenery in $filteredScenery.GetEnumerator())
{
    Write-Host "Traitement de: $($scenery.Value.Local)"
    $repScenTmp = $($scenery.Value.Local).Replace("\","_").replace(":","_")
    $sceneryTemp = "$tempRep\$repScenTmp"
    New-Item -ItemType Directory -Path $sceneryTemp

    $bglScenery = Get-ChildItem $scenery.Value.Local -Filter "*.bgl" -Recurse

    foreach($bgl in $bglScenery)
    {
        Write-Host "... $($bgl.name)"
        #$cmd = ".\Bgl2Xml170\Bgl2Xml.exe `"$($bgl.FullName)`" `"$sceneryTemp\$($bgl.name).xml`" `"no`""
        #$res = Invoke-Expression -Command $cmd

        $proc = Start-Process -filePath ".\Bgl2Xml186\Bgl2Xml.exe" -ArgumentList "`"$($bgl.FullName)`" `"$sceneryTemp\$($bgl.name).xml`" `"no`""  -PassThru -NoNewWindow
        
        # keep track of timeout event
        $timeouted = $null # reset any previously set timeout

        # wait up to x seconds for normal termination
        $proc | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue -ErrorVariable timeouted

        if ($timeouted)
        {
            # terminate the process
            $proc | kill

            # update internal error counter
        }
        elseif ($proc.ExitCode -ne 0)
        {
            throw "Erreur sa mère"
        }

        #$cmd = ".\Bgl2Xml170\Bgl2Xml.exe `"$($bgl.FullName)`" `"$sceneryTemp\$($bgl.name).xml`" `"no`""
        #$res = Invoke-Expression -Command $cmd
        

        #$LASTEXITCODE
        if($res -like "*UNKNOWN")
        {
            Remove-Item "$sceneryTemp\$($bgl.name).xml" -Force -Confirm:$false
        }
        elseif(Test-Path "$sceneryTemp\$($bgl.name).xml") {
            [xml]$xml = Get-COntent "$sceneryTemp\$($bgl.name).xml"
            
            try {
                if($xml.FSData.Airport -ne $null)
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
                    

                    #Read-Host "totototo"
                    $airport = @{
                        "OACI" = $($xml.FSData.Airport.ident) ;
                        "Country" = $($xml.FSData.Airport.country) ;
                        "City" = $($xml.FSData.Airport.city);
                        "Latitude" = [double]$($xml.FSData.Airport.lat);
                        "Longitude" = [double]$($xml.FSData.Airport.lon);
                        "Altitude" = $($xml.FSData.Airport.alt);
                        "Name" = $($xml.FSData.Airport.name);
                        "State" = $($xml.FSData.Airport.state);
                        "RunwayArea" = $TotalRunwaySurface;
                        "AirportSize" = $airportSize
                    }
                    $dataAirport.Add($xml.FSData.Airport.ident , $airport)
                }
                else {
                    Remove-Item "$sceneryTemp\$($bgl.name).xml" -Force -Confirm:$false
                }
                        
            }
            catch {
                Write-Host "$($bgl.name) - Not a valid airpot file !"
            }
    
        }
        else {
            Write-Host "$($bgl.name) - Xml non généré"
        }
    }

    Remove-Item -Path $sceneryTemp -Force -Confirm:$false -Recurse

}

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
       $kml.kml.AppendChild($kml.ImportNode($kmlPlacemark.Placemark,$true))
    }

    $kml.Save("$PSScriptRoot\$($group.Name)_Airports.kml")
}