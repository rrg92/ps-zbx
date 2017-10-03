param($VALUES)

Log "	Restoring permissions"

$PermissionsList 	= $VALUES.DESTINATION_INFO.PERMISSIONS


if(!$PermissionsList){
	Log "	No backed up permissions found. Skipping."
	return;
}

try {

	Log "	Creating principals"
	
	$PermissionsList.PRINCIPALS| where {$_} | %{
		try {
			$tsql = (. $VALUES.SCRIPT_STORE.SQL.GET_PRINCIPAL_DCL $_.principalName $_.serverPrincipal $_.type_desc)	
		
			Log "		Creating the principal ($($_.type_desc)) $($_.principalName) mapped to $($_.serverPrincipal)"
			Log "		Create principal command: $tsql"
			& $SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $tsql -NoExecuteOnSuggest
			Log "			SUCCESS!"
		} catch {
			Log "	Error when creating principal: $_";
		}
	}
	
	Log "	Creating role memberships"
	
	$PermissionsList.ROLES_MEMBERS | where {$_}  | %{
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_ROLEMEMBERSHIP_DCL $_.roleName $_.memberName
			
			Log "		Adding principal $($_.memberName) to $($_.roleName)"
			Log "		Role membership command: $tsql"
			& $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $tsql -NoExecuteOnSuggest
			Log "			SUCCESS!"
		} catch {
			Log "	Error when adding role membership: $_";
		}
	}
	
	Log "	Creating permissions"
	
	$PermissionsList.PERMISSIONS | where {$_} | %{
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_PERMISSIONS_DCL $_.principalName $_.permission_name $_.PermissionState $_.SecurableClass $_.SecurableName $_.SecurableMinorName
			
			Log "		Permission DCL: $tsql"
			& $VALUES.SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $tsql -NoExecuteOnSuggest
			Log "			SUCCESS!"
		} catch {
			Log "	Error when assigning permission: $_";
		}
	}
	
	if($PermissionsList.DBO){
	
	Log "	Changing the owner"
	
		$OwnerPrincipal = $PermissionsList.DBO.Owner;
		try {
			$tsql = . $VALUES.SCRIPT_STORE.SQL.GET_OWNER_DCL $OwnerPrincipal;
			Log "		Changing the database owner to $OwnerPrincipal"
			& $SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $tsql -NoExecuteOnSuggest
			Log "			SUCCESS!"
		} catch {
			Log "	Error when changing the owner: $_";
		}
	}
} catch {
	Log $_
	Log	"Error when restoring permissions. Check previous errors."
}