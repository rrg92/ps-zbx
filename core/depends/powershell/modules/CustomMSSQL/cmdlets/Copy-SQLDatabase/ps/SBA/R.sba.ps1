return @{
	NAME = "RECENT BACKUP SOURCE"
	SCRIPT = {
		param($VALUES)
		
			$UseRecentBackup = $VALUES.PARAMS.UseRecentBackup;
			$UseExistentPolicy = $VALUES.PARAMS.UseExistentPolicy;
			$RecentFileMask = $VALUES.PARAMS.RecentFileMask;
			$RecentBase = $VALUES.PARAMS.RecentBase;
			$BackupFolder = (PutFolderSlash $VALUES.PARAMS.BackupFolder);
			$LogFn = $VALUES.SCRIPT_STORE.FUNCTIONS.Log;
				
			if(!$UseRecentBackup)
			{
				& $LogFn "		UseRecentBackup dont was passed." "VERBOSE"
				return;
			}
			
			
			& $LogFn "		Using a recent existent backup file"
				
			[datetime]$RecentBaseDatetime = 0;
				
			if($RecentBase){
				$RecentBaseDatetime = [datetime]$RecentBase;
				& $LogFn "		Recently base is: $RecentBaseDatetime"
			}
				
			try {
				$BackupName = $VALUES.BACKUP_FILEPREFIX+"*"+$VALUES.BACKUP_FILESUFFIX 
				
				if($RecentFileMask){
					$BackupName = $RecentFileMask;
				}
				
				& $LogFn "		Looking for $BackupName in $BackupFolder"
				$backupFile = gci ($BackupFolder+$BackupName) | where {$_.LastWriteTime -ge $RecentBaseDatetime} | sort LastWriteTime -desc | select -First 1 | %{$_.FullName}

				$SBA = (NewSourceBackup)
				$SBA.fullPath = $backupfile;
			} catch {
				& $LogFn "	Error getting most recent backup file: $_"
			} finally {
				if(!$backupFile){
					& $LogFn "		No backups found!"
					& $LogFn "		Existent Policy is: $UseExistentPolicy"	
					
					if($UseExistentPolicy -eq "MustUse"){
						throw "NO_RECENT_BACKUP_FOUND"
					}
				}
			}
		
	
		return $SBA;
	}
}

