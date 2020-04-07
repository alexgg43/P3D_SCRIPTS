$bgls = "c:\bgls"
$xmls = "c:\xmls"

$bglToXmlPath = "C:\Bgl2Xml\Bgl2Xml.exe"

$bglScenery = (Get-ChildItem $bgls -Filter "*.bgl" -Recurse | where-object {$_.length -gt 2KB})

for ($i = 0; $i -lt $bglScenery.Count; $i++) {
    $proc = Start-Process -filePath $bglToXmlPath -ArgumentList "`"$($bglScenery[$i].FullName)`" `"$xmls\$($bglScenery[$i].BaseName).xml`" `"no`""  -NoNewWindow -PassThru -RedirectStandardOutput NUL

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

    if(Test-Path -Path "$($xmls)\$($bglScenery[$i].BaseName).xml"){
        if((Get-Item -Path "$($xmls)\$($bglScenery[$i].BaseName).xml").Length -lt 2KB){
            Remove-Item "$($xmls)\$($bglScenery[$i].BaseName).xml" -Force -Confirm:$false
        }
    }
}
