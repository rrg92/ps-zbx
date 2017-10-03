
Function Get-CustomMSSQLVersions {
	[CmdLetBinding()]
	param(

	)
	$ErrorActionPreference = "Stop";

	return (GetVersions);
	
	<#
		.SYNOPSIS 
			Returns the versions list and dates of the module, in changelog!
			
		.DESCRIPTION
			This cmdlet will dump the CHANGELOG.md and returns the list of versions and date.
		
		.EXAMPLE
			Get-CustomMSSQLVersions
			
		.NOTES
		
			

	#>
}

Function Get-CustomMSSQLVersionChangeLog {
	[CmdLetBinding()]
	param(
		$Version = $null
	)
	$ErrorActionPreference = "Stop";

	return (GetVersionChangeLog $Version);
	
	<#
		.SYNOPSIS 
		
		.DESCRIPTION
		
		.EXAMPLE
			
			
		.NOTES
		
			

	#>
}