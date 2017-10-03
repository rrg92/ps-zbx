Function Get-SQLAgentOptions {
	[CmdLetBinding()]
	param($InstanceName = $null, $Option = $null, [switch]$SingleOnly = $false,$HashOptions = $null)

	$ErrorActionPreference = "Stop";
	$defaultProperties = "PSPath","PSPArentPath","PSChildName","PSDrive","PSProvider"

	$instName = (Get-SQLFullInstanceName -InstanceName $InstanceName)

	$Path = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($instName.FullName)\SQLServerAgent"
	  
	if($HashOptions){
		$HashOptions.add("FullPath",$Path);
	}


	try {
		$regValues = Get-ItemProperty -Path $Path -Name $Option
		if(!$regValues){
			throw "NOTHING_FOUND";
		}
		
	} catch {
		write-verbose "Error getting property: $($_.Exception.Message)"
		return $null
	}


	$instNames = @($regValues | gm -Type Noteproperty | where {-not($defaultProperties -Contains $_.Name)} | %{$_.Name})

	$result = @()

	$instNames | %{
		$prop = $_
		$o = New-Object PSObject -Prop @{Option=$_;Value=$regValues.$prop};
		
		$result += $o
	}

	if(@($result).count -gt 1 -and $SingleOnly){
		throw "NON_UNIQUE"
	}

	return $result
}