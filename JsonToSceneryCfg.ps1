

function BooleanToString
{
  param
  (
    $value
  )
  switch ($value)
  {
    $true { return "TRUE" }
    $false { return "FALSE" }
    default { return $value }
  }
}


$file = "$PSScriptRoot\sceneryCountryGroups.cfg.json"

#$data = (Parse-IniFile $file).GetEnumerator() | sort Key  #Transforme en array
#$data = (Parse-IniFile $file)

$outputFile = "$PSScriptRoot\sceneryCountryGroups.cfg"

$sceneryJson = (Get-Content $file | ConvertFrom-Json -AsHashtable)

if(Test-Path $outputFile)
{
  Remove-Item $outputFile -Force -Confirm:$false
}

$strToAdd = "[General]"

foreach($row in $sceneryJson["General"].GetEnumerator())
{
  $strToAdd = $strToAdd + "`r`n$($row.name)=$($row.Value)" 
}
$strToAdd = $strToAdd + "`r`n"

$strToAdd | Add-Content $outputFile -Encoding unicode

$orderedKeys = $sceneryJson.keys | Where {!($_ -like "General")} | Sort


foreach($key in $orderedKeys)
{
  $strToAdd = "[$key]"
  foreach($row in $sceneryJson[$key].GetEnumerator())
  {
    if($row.name -ne "Groups")
    {
      $strToAdd = $strToAdd + "`r`n$($row.name)=$(BooleanToString $row.Value)" 
    }
    else {
      $strToAdd = $strToAdd + "`r`nX_Groups=$($row.Value -join ',')"
    }
    
  }
  $strToAdd = $strToAdd + "`r`n"

  $strToAdd | Add-Content $outputFile -Encoding unicode
}
