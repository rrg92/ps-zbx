Function Set-CMSPropsRepository {
	[CmdletBinding()]
	param(
		#This is the server instance. You can specify any valid connection to a SQL Instance.
			[string]
			$ServerInstance
		
		,#This is the database name
			[string]
			$Database
	)
	$ErrorActionPreference = "Stop";
	
	$CMSPropsSlot = (GetVarSlot "CMSPROPS")
	
	UpdateVarSlot -slot $CMSPropsSlot -VarName "ServerInstance" -Value $ServerInstance
	UpdateVarSlot -slot $CMSPropsSlot -VarName "Database" -Value $Database
	
	return;
}

Function Get-CMSPropsRepository {
	[CmdletBinding()]
	param()
	$ErrorActionPreference = "Stop";
	
	$CMSPropsSlot = (GetVarSlot "CMSPROPS")
	
	return @{ServerInstance=$CMSPropsSlot.ServerInstance;Database=$CMSPropsSlot.Database};
}

Function Install-CMSPropsRepository {
	param(
		$ServerInstance
		,$Database
	)
	
	$ScriptOrders =@(
			"cmsprops.sch.sql"
			"cmsprops.CMSProperties.tab.sql"
			"cmsprops.cpInstanceProperties.vw.sql"
		)
	
	
}