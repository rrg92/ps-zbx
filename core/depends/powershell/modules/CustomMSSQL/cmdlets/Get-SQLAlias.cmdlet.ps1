Function Get-SQLAlias {
	[CmdLetBinding()]
	param($AliasName = $null)

	 
	#These are the two Registry locations for the SQL Alias locations
	$x86 = "HKLM:\Software\Microsoft\MSSQLServer\Client\ConnectTo"
	$x64 = "HKLM:\Software\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo"
	 
	$defaultProperties = "PSPath","PSPArentPath","PSChildName","PSDrive","PSProvider"

	$x86Reg		= Get-ItemProperty -Path $x86 -EA SilentlyContinue
	$x86Aliases = @($x86Reg	 | gm -Type Noteproperty | where {-not($defaultProperties -Contains $_.Name)} | %{$_.Name})

	$x64Reg		= Get-ItemProperty -Path $x64 -EA SilentlyContinue
	$x64Aliases = @($x64Reg	 | gm -Type Noteproperty | where {-not($defaultProperties -Contains $_.Name)} | %{$_.Name})


	$result = @()

	$x86Aliases | %{
		$prop = $_
		$result += New-Object PSObject -Prop @{AliasName=$_;Value=$x86Reg.$prop;Source="P"}
	}

	$x64Aliases | %{
		$prop = $_
		$result += New-Object PSObject -Prop @{AliasName=$_;Value=$x86Reg.$prop;Source="WOW64"}
	}


	return $result
}