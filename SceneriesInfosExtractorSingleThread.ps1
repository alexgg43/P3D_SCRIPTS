cls

$tempRep = "$PSScriptRoot\Temp"
New-Item -ItemType Directory -Path $tempRep -ErrorAction SilentlyContinue
Remove-Item "$tempRep\*" -Force -Confirm:$false -Recurse

$dataAirport = @{}

$pathP3DSceneryDefault = "G:\Prepar3D v4\Scenery"
$excludeListPath = "ExclusionsRegex.csv"
$bglToXmlPath = "C:\Bgl2Xml186\\Bgl2Xml.exe"

$excludeRegex = $(Get-Content $excludeListPath) -Join "|"

$fileJSon = "$PSScriptRoot\scenery.cfg.json"

$sceneryJson = (Get-Content $fileJSon | ConvertFrom-Json -AsHashtable)

$filteredScenery = @{}
foreach ($hash in $sceneryJson.GetEnumerator())
{
    if(!(($hash.Value.Local -like "$pathP3DSceneryDefault\*") -or ($hash.Value.Title -match $excludeRegex) -or ($hash.Name -like "General")))
    {
        $filteredScenery.Add($hash.Name , $hash.value)
    }
}


foreach($scenery in $filteredScenery.GetEnumerator())
{
    Write-Host "Traitement de: $($scenery.Value.Local)"
    $repScenTmp = $($scenery.Value.Local).Replace("\","_").replace(":","_")
    $sceneryTemp = "$tempRep\$repScenTmp"
    New-Item -ItemType Directory -Path $sceneryTemp | Out-Null

    $bglScenery = Get-ChildItem $scenery.Value.Local -Filter "*.bgl" -Recurse

    foreach($bgl in $bglScenery)
    {
        $proc = Start-Process -filePath $bglToXmlPath -ArgumentList "`"$($bgl.FullName)`" `"$sceneryTemp\$($bgl.name).xml`" `"no`""  -NoNewWindow -PassThru 

        # keep track of timeout event
        $timeouted = $null # reset any previously set timeout

        # wait up to x seconds for normal termination
        $proc | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue -ErrorVariable $timeouted

        if ($timeouted)
        {
            # terminate the process
            Write-Host "toto"
            $proc | kill

            # update internal error counter
        }
        elseif ($proc.ExitCode -ne 0)
        {
            Write-Host "!!--ExitCode != 0--!!"
        }

        [xml]$xml = Get-Content "$sceneryTemp\$($bgl.name).xml" -ErrorAction Break
        
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
                Remove-Item "$sceneryTemp\$($bgl.name).xml" -Force -Confirm:$false
            }
                    
        }
        catch {
            Write-Host "$($bgl.name) - Not a valid airpot file !"
        }

        <# if($res -like "*UNKNOWN")
        {
            Remove-Item "$sceneryTemp\$($bgl.name).xml" -Force -Confirm:$false
        }
        else if(Test-Path "$sceneryTemp\$($bgl.name).xml") {
            [xml]$xml = Get-Content "$sceneryTemp\$($bgl.name).xml"
            
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
                    Remove-Item "$sceneryTemp\$($bgl.name).xml" -Force -Confirm:$false
                }
                        
            }
            catch {
                Write-Host "$($bgl.name) - Not a valid airpot file !"
            }
    
        }
        else {
            Write-Host "$($bgl.name) - Xml non généré"
        } #>
    }

    Remove-Item -Path $sceneryTemp -Force -Confirm:$false -Recurse
}

$dataAirport

