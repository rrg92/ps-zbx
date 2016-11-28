#Este arquivo define todos as keys usadas em low level discovery.

@{
	#"LLD:mssql.discovery[Databases]"	= "<DIRSCRIPTS>\sql\discoveryDatabases.sql"
	"LLD:mssql.discovery[NumaPLE]"		= "<DIRSCRIPTS>\sql\discoveryNumaNodePLE.sql"
	"LLD:mssql.discovery[SQLPerfCounters]"	= "<DIRSCRIPTS>\sql\discoverySQLPerfCounters.sql"
	
	<#
	"LLD:mssql.discovery[Volumes]"		= { param($V) 
												
												$Params = @{
													Instance = $V.USER.INSTANCE_NAME
													GetLocally = $true
												}
												
												$ScriptPath = $V.PARAMS.DirScripts+"\"+"ps\Get-InstanceVolumes.ps1"
	
												& $ScriptPath @Params
											}
	#>
}