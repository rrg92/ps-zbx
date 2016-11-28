param($VALUES)

$ReplaceOption = "";
if($Replace){
	$ReplaceOption = ",REPLACE"
}

$NoRecoveryOption = ""
if($VALUES.PARAM.NoRecovery){
	$NoRecoveryOption = ",NORECOVERY"
}


$BaseCommand = 
"
RESTORE DATABASE
	[$DestinationDatabase]
FROM	
	DISK = '$($VALUES.SOURCE_BACKUP.fullPath)'
WITH	
	STATS = 10	
	$ReplaceOption
	$NoRecoveryOption 
"
	
return $BaseCommand;