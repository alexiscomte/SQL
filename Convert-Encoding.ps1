Param (
    [Parameter(Mandatory=$True)][String]$SourcePath,
	[Parameter(Mandatory=$True)][String]$DestPath
)

$global:gitbin = 'C:\Program Files\Git\usr\bin'
$global:apexbin = 'C:\Program Files\ApexSQL\ApexSQL Refactor\'
Set-Alias file.exe $gitbin\file.exe
Set-Alias APEXSQLREFACTOR.EXE $apexbin\APEXSQLREFACTOR.EXE

function Get-FileEncoding
{
    [CmdletBinding()] Param (
     [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [string]$Path
    )
   $return = file.exe $Path  
  return $return -match "UTF-8"
}



Get-ChildItem $SourcePath\*  -recurse -Include *.sql | ForEach-Object {
	
	if (-not (Get-FileEncoding $_.Fullname) ) 
	{
		Write-Output $_.Fullname
		Write-Output "Convert to UTF-8 BOM"
		$Dest = $DestPath + "\" + $_.Name
		$Dest = $Dest -replace ".SQL", ".sql"
		Write-Output $Dest
		(Get-Content $_) | Set-Content -Encoding UTF8 -Path $Dest
		Write-Output "APEX FORMAT"
		APEXSQLREFACTOR.EXE /f /is:$Dest  /frs /pf:"ADS"  /v
	}
}
