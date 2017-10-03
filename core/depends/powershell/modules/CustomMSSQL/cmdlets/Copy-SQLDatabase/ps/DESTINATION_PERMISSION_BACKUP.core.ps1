param($VALUES)

Log "	Getting all permissions for apply after restore."

$ExportFile	= $VALUES.Params.ExportPermissionsFile;

Function ExportToFile {
	param($tsql)
	
	if(!$ExportFile){
		return;
	}
	
	$GO = "`r`nGO`r`n"
	
	try {
		$tsql+$GO >> $ExportFile
	} catch {
		Log "	Exporting to file failed: $_" "PROGRESS"
	}
}

$PermissionsList = @{
	PRINCIPALS=@()
	DBO=@()
	ROLES_MEMBERS=@()
	PERMISSIONS=@()
}

$VALUES.DESTINATION_INFO.ADD("PERMISSIONS",$PermissionsList);

$BackupPrincipalsCommand 	= & $VALUES.SCRIPT_STORE.SQL.GET_PRINCIPALS
$BackupDboCommand 			= & $VALUES.SCRIPT_STORE.SQL.GET_DBO
$BackupRoleMembersCommand 	= & $VALUES.SCRIPT_STORE.SQL.GET_ROLEMEMBERSHIP
$BackupPermissionsCommand	= & $VALUES.SCRIPT_STORE.SQL.GET_PERMISSIONS

try {
	Log "		Getting current principals..."
	$PermissionsList.PRINCIPALS = & $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $BackupPrincipalsCommand
	Log "			total principals: $(@($PermissionsList.PRINCIPALS).count)"
		
	Log "		Getting current database owner..."
	$PermissionsList.DBO = & $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $BackupDboCommand
	Log "			Current Owner: $($PermissionsList.DBO.Owner)"
	
	Log "		Getting roles memberships..."
	$PermissionsList.ROLES_MEMBERS = & $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $BackupRoleMembersCommand
	Log "			total memberships: $(@($PermissionsList.ROLES_MEMBERS).count)"
	
	Log "		Getting permissions..."
	$PermissionsList.PERMISSIONS = & $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $BackupPermissionsCommand
	Log "			total permissions: $($PermissionsList.PERMISSIONS.count)"
} catch {
	Log $_
	Log	"Error when getting permissions. Check previous errors."
}


if($ExportFile){
	try {
		Log "	Attempting initialize file for export permissons: $ExportFile"
		"-- Export permissions, started on "+((Get-Date).toString("yyyyMMdd HH:mm:ss")) > $ExportFile
	} catch {
		Log "		FAILED: $_";
		$ExportFile = $null;
	}
	
	Log "	Exporting DCL principals..."
	$PermissionsList.PRINCIPALS| where {$_} | %{
		try {
			$tsql = (. $VALUES.SCRIPT_STORE.SQL.GET_PRINCIPAL_DCL $_.principalName $_.serverPrincipal $_.type_desc)	
			ExportToFile $tsql
		} catch {
			Log "		Error: $_";
		}
	}
	
	Log "	Exporting DCL role membership..."
	$PermissionsList.ROLES_MEMBERS | where {$_}  | %{
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_ROLEMEMBERSHIP_DCL $_.roleName $_.memberName
			ExportToFile $tsql
		} catch {
			Log "		Error: $_";
		}
	}
	
	Log "	Exporting DCL permissions..."
	$PermissionsList.PERMISSIONS | where {$_} | %{
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_PERMISSIONS_DCL $_.principalName $_.permission_name $_.PermissionState $_.SecurableClass $_.SecurableName $_.SecurableMinorName
			ExportToFile $tsql
		} catch {
			Log "		Error: $_";
		}
	}
	
	if($PermissionsList.DBO){
		Log "	Exporting DCL owner..."
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_OWNER_DCL $PermissionsList.DBO.Owner;
			ExportToFile $tsql;
		} catch {
			Log "		Error: $_";
		}
	}		
			
}	



