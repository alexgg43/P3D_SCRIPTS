function Parse-IniFile ($file)
{
  $ini = @{}
  switch -regex -file $file
  {
    #Section.
    "^\[(.+)\]$"
    {
      $section = $matches[1].Trim()
      $ini[$section] = @{}
      continue
    }
    #Int.
    "^\s*([^#].+?)\s*=\s*(\d+)\s*$"
    {
      $name,$value = $matches[1..2]
      $ini[$section][$name] = [int]$value
      continue
    }
    #Bool.
    "^\s*([^#].+?)\s*=\s*(TRUE|FALSE)\s*$"
    {
      $name,$value = $matches[1..2]
      $ini[$section][$name] = ConvertTo-Boolean($value)
      continue
    }
    #Decimal.
    "^\s*([^#].+?)\s*=\s*(\d+\.\d+)\s*$"
    {
      $name,$value = $matches[1..2]
      $ini[$section][$name] = [decimal]$value
      continue
    }
    #Groups.
    "^\s*X_(Groups)\s*=\s*(.*)\s*$"
    {
      $name,$value = $matches[1..2]
      $ini[$section][$name] = $value.Trim().Split(',')
      continue
    }
    #Everything else.
    "^\s*([^#].+?)\s*=\s*(.*)"
    {
      $name,$value = $matches[1..2]
      $ini[$section][$name] = $value.Trim()
    }
  }
  return $ini
}

function ConvertTo-Boolean
{
  param
  (
    [Parameter(Mandatory=$false)][string] $value
  )
  switch ($value)
  {
    "y" { return $true; }
    "yes" { return $true; }
    "true" { return $true; }
    "t" { return $true; }
    1 { return $true; }
    "n" { return $false; }
    "no" { return $false; }
    "false" { return $false; }
    "f" { return $false; } 
    0 { return $false; }
  }
}


$file = "C:\ProgramData\Lockheed Martin\Prepar3D v4\scenery.cfg"

#$data = (Parse-IniFile $file).GetEnumerator() | sort Key  #Transforme en array
$data = (Parse-IniFile $file)

$jsonfile = ConvertTo-Json -InputObject $data

$jsonfile | Set-Content -Path $PSScriptRoot\scenery.cfg.json -Encoding Unicode

