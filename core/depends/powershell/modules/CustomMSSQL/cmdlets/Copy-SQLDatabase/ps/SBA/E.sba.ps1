@{
	NAME = "EXISTENT BACKUP"
	SCRIPT = {
		param($VALUES)
		
		$ExistentBackupName = $VALUES.PARAMS.ExistentBackupName;
		$UseExistentPolicy = $VALUES.PARAMS.UseExistentPolicy;
		$LogFn = $VALUES.SCRIPT_STORE.FUNCTIONS.Log;
		
		
		if(!$ExistentBackupName){
			& $LogFn "		ExistentBackupName wasn't passed." "VERBOSE"
			return;
		}
		

		& $LogFn  "	Using file $ExistentBackupName"

	
		try{
			$backupfile = (gi $ExistentBackupName) | %{$_.FullName}
			$SBA = (NewSourceBackup)
			$SBA.fullPath = $backupfile;
		} catch {
			& $LogFn  "		Error getting existent files: $_"
		} finally {
			if(!$backupFile){
				& $LogFn  "		No backups found!"
				& $LogFn  "		Existent Policy is: $UseExistentPolicy"	
				if($UseExistentPolicy -eq "MustUse"){
					throw "NO_EXISTENT_BACKUP_NAME_FOUND"
				}
			}
		}
			
		
		return $SBA;
	}
}

