Function Get-NumericSQLVersion {
	[CmdLetBinding(SupportsShouldProcess=$True)]
	param(
		#This is the SQL Version. Use SELECT SERVERPROPERTY('ProductVersion') to get the value.
			[string]$Version
	)
	$ErrorActionPreference = "Stop";

	return (GetProductVersionNumeric $Version);
	
	<#
		.SYNOPSIS 
			Returns SQL Server a numeric representation of a SQL Server product version
			
		.DESCRIPTION
			This cmdlet get a Product version and returns a numeric representation, that you can use to compare.
			You must provide a valid version in format Major.Minor.Build. 
			Check this link for more detail about version: https://msdn.microsoft.com/en-us/library/ms143694.aspx
			For example, the version "10.20.1111" is returned as 10.201111.
		
		.EXAMPLE
			
			
		.NOTES
		
			

	#>
}
