$bgls = "c:\bgls"
$xmls = "c:\xmls"

$bglToXmlPath = "C:\Bgl2Xml\Bgl2Xml.exe"

$bglScenery = (Get-ChildItem $bgls -Filter "*.bgl"<#  | where-object {$_.length -gt 1KB} #>)

for ($i = 0; $i -lt $bglScenery.Count; $i++) {
    try {
        $er = (Invoke-Expression "$($bglToXmlPath) `"$($bglScenery[$i].FullName)`" `"$xmls\$($bglScenery[$i].BaseName).xml`" `"no`"") 2>&1
        <# $proc = Start-Process -filePath $bglToXmlPath -ArgumentList "`"$($bglScenery[$i].FullName)`" `"$xmls\$($bglScenery[$i].BaseName).xml`" `"no`""  -NoNewWindow -PassThru -RedirectStandardOutput NUL -RedirectStandardError NUL

        # wait up to x seconds for normal termination
        $proc | Wait-Process -Timeout 60 -ErrorAction SilentlyContinue #-ErrorVariable $timeouted
    
        if ($proc.ExitCode -ne 0)
        {
            Write-Host "!!--ExitCode != 0--!!"
        } #>
    }catch{
        Write-Host $PSItem.Exception.Message -ForegroundColor Red
    }


    <# if(Test-Path -Path "$($xmls)\$($bglScenery[$i].BaseName).xml"){
        if((Get-Item -Path "$($xmls)\$($bglScenery[$i].BaseName).xml").Length -lt 1KB){
            Remove-Item "$($xmls)\$($bglScenery[$i].BaseName).xml" -Force -Confirm:$false
        }
    } #>
}
