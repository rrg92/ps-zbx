Function Get-SQLFullInstanceName {
	[CmdLetBinding()]
	param($InstanceName = $null,[switch]$All,[switch]$GetVersion = $false)

	$ErrorActionPreference = "Stop";
	$defaultProperties = "PSPath","PSPArentPath","PSChildName","PSDrive","PSProvider"
	$Path = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
	 
	if(!$InstanceName) {
		$InstanceName = "MSSQLSERVER"
	}
	 
	if($All){
		$InstanceName = $null
	}
	 
	if(Test-Path $Path){
		$regValues = Get-ItemProperty -Path $Path -Name $InstanceName
	} else {
		return $null
	}

	$instNames = @($regValues	 | gm -Type Noteproperty | where {-not($defaultProperties -Contains $_.Name)} | %{$_.Name})

	$result = @()

	$VersionPathKey = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\{0}\MSSQLServer\CurrentVersion'
	$instNames | %{
		$prop = $_
		$InstanceInfo = New-Object PSObject -Prop @{InstanceName=$_;FullName=$regValues.$prop;Version=$null;Errors=@{}}

		if($GetVersion){
			try {
				$InstanceVersionKey = ($VersionPathKey -f $InstanceInfo.FullName)
				$InstanceInfo.Version = (Get-ItemProperty -Path $InstanceVersionKey -Name "CurrentVersion").CurrentVersion
			} catch {
				$InstanceInfo.Errors.add("VERSION",$_);
			}
		}
		
		$result	+= $InstanceInfo;
	}

	return $result
}