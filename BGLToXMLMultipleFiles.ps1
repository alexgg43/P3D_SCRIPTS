cls

Add-Type -AssemblyName System.Windows.Forms

$tempRep = "$PSScriptRoot\Temp"
$sceneryTemp = "$tempRep\"
New-Item -ItemType Directory -Path $tempRep -ErrorAction SilentlyContinue
Remove-Item "$tempRep\*" -Force -Confirm:$false -Recurse

$bglToXmlPath = "H:\Tools\Bgl2Xml186\Bgl2Xml.exe"
$bglCompPath = "G:\Prepar3D v4 SDK 4.5.13.32097\World\Scenery\bglcomp.exe"

$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = 'H:\Tools\Works' 
    Filter = 'Documents (*.bgl)|*.bgl'
    Multiselect = $true
}
$null = $FileBrowser.ShowDialog()


for ($i = 0; $i -lt $FileBrowser.FileNames.Count; $i++) {
    $proc = Start-Process -filePath $bglToXmlPath -ArgumentList "`"$($FileBrowser.FileNames[$i])`" `"$sceneryTemp\$($FileBrowser.SafeFileNames[$i]).xml`" `"no`""  -NoNewWindow -PassThru -RedirectStandardOutput "$($sceneryTemp)\$($FileBrowser.SafeFileNames[$i]).txt"

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

    $ret = Get-Content -Path "$($sceneryTemp)\$($FileBrowser.SafeFileNames[$i]).txt"
    Remove-Item "$($sceneryTemp)\$($FileBrowser.SafeFileNames[$i]).txt" -Force -Confirm:$false
    if ($ret.Contains("UNKNOWN")){
        Remove-Item "$($sceneryTemp)\$($FileBrowser.SafeFileNames[$i]).xml" -Force -Confirm:$false
    }else{
        $proc = Start-Process -filePath $bglCompPath -ArgumentList "`"$sceneryTemp\$($FileBrowser.SafeFileNames[$i]).xml`""  -NoNewWindow -PassThru -RedirectStandardOutput "$($sceneryTemp)\$($FileBrowser.SafeFileNames[$i]).txt"

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
        $compRet = Get-Content "$($sceneryTemp)\$($FileBrowser.SafeFileNames[$i]).txt"

        Remove-Item "$($sceneryTemp)\$($FileBrowser.SafeFileNames[$i]).txt" -Force -Confirm:$false
        Remove-Item "$($sceneryTemp)\$($FileBrowser.SafeFileNames[$i]).xml" -Force -Confirm:$false

        Rename-Item "$($sceneryTemp)\$($FileBrowser.SafeFileNames[$i]).bgl" "$($sceneryTemp)\$($FileBrowser.SafeFileNames[$i])" -ErrorAction SilentlyContinue

    }
}
