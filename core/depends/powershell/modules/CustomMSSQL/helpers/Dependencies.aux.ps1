#Finds most recent version of SMO and loads it

Function LoadSMO {
	$ErrorActionPreference = "Stop";
	
	$assemblylist = @(
		"Microsoft.SqlServer.Management.Common"
		"Microsoft.SqlServer.Smo"
		"Microsoft.SqlServer.Dmf"
		"Microsoft.SqlServer.DmfSqlClrWrapper"
		"Microsoft.SqlServer.Dmf.Adapters"
		"Microsoft.SqlServer.Instapi"
		"Microsoft.SqlServer.SqlWmiManagement"
		"Microsoft.SqlServer.ConnectionInfo"
		"Microsoft.SqlServer.SmoExtended"
		"Microsoft.SqlServer.SqlTDiagM"
		"Microsoft.SqlServer.SString"
		"Microsoft.SqlServer.Management.RegisteredServers"
		"Microsoft.SqlServer.Management.Sdk.Sfc"
		"Microsoft.SqlServer.SqlEnum"
		"Microsoft.SqlServer.RegSvrEnum"
		"Microsoft.SqlServer.WmiEnum"
		"Microsoft.SqlServer.ServiceBrokerEnum"
		"Microsoft.SqlServer.ConnectionInfoExtended"
		"Microsoft.SqlServer.Management.Collector"
		"Microsoft.SqlServer.Management.CollectorEnum"
		"Microsoft.SqlServer.Management.Dac"
		"Microsoft.SqlServer.Management.DacEnum"
		"Microsoft.SqlServer.Management.Utility"
	)
	
	foreach($asm in $assemblylist){
		$asm = [Reflection.Assembly]::LoadWithPartialName($asm)
	}
	
	return;
	
	<#
	$PossibleVersions = 130,120,110,100
	$BaseFolder = "C:\Program Files\Microsoft SQL Server\{0}\SDK\Assemblies\"
	#Determine alternate folder version!
	$LastQtd = 0
	$ElegibleFolder = ""
	$PossibleVersions | %{
		$CurrentFolder = $BaseFolder -f  $_
		$qtdAvailable = @(gci -EA "SilentlyContinue" @($assemblylist|%{"$CurrentFolder\*$_*"})).count
		if($qtdAvailable -gt $LastQtd){
			$ElegibleFolder = $CurrentFolder
		}
	}
	
	$assemblies = gci ($ElegibleFolder+"\*.dll")
	
	foreach ($asm in $assemblies)
	{
			$fullPath = $asm.FullName
			try{
				[Reflection.Assembly]::LoadFrom($fullPath)  | out-Null
			} catch {
				if($assemblylist -contains $asm){
					throw
				}
			}
	}
	#>

}

Function ImportDependencieModule {
	param($ModuleName,[hashtable]$ExtraArgs = @{})

	$g = GetGMV;
	$modulesDir = $g.MODULESDIR
	
	
	@($ModuleName) | %{
		$FullPathToModule = $modulesDir + "\" + $_;
		
		$Params = @{
			Name = $FullPathToModule
		} + $ExtraArgs;
		
		write-verbose "ImportDependencieModule: Importing... $($Params.Name)";
		import-module @Params;
	}
}