<#
	This is SQL Source Backup Algorithm (SBA)
	This script is responsible for generating a backup directly from a SQL Server instance.
	ITs returns the backup file.
#>

@{
	NAME = "SQL SERVER SOURCE"
	SCRIPT = {
		param($VALUES)
		
			
			$SourceServerInstance = $VALUES.PARAMS.SourceServerInstance;
			$SourceDatabase = $VALUES.PARAMS.SourceDatabase;
			$SourceReadOnly = $VALUES.PARAMS.SourceReadOnly;
			$LogFn = $VALUES.SCRIPT_STORE.FUNCTIONS.Log;
			
		
			& $LogFn "		Generating a new database backup of $SourceDatabase in $SourceServerInstance"
			
			if($SourceReadOnly){
				& $LogFn "		Source Database will be put in READ_ONLY before backup."
				$ReadOnlyCommand =  . $VALUES.SCRIPT_STORE.SQL.PUT_DATABASE_READONLY $VALUES
				& $LogFn "			ReadOnly command: $ReadOnlyCommand"
				$results = & $VALUES.SQLINTERFACE.cmdexec -S $SourceServerInstance -d master -Q $ReadOnlyCommand -NoExecuteOnSuggest
			}
				
			
			$BackupCommand =  . $VALUES.SCRIPT_STORE.SQL.BACKUP_DATABASE $VALUES
				
			& $LogFn "		Backup command: $BackupCommand"
			
			$results = & $VALUES.SQLINTERFACE.cmdexec -S $SourceServerInstance -d master -Q $BackupCommand -NoExecuteOnSuggest
			$SBA = (NewSourceBackup)
			
			if($results){
				$backupFile = $results.backupfile
				$SBA.fullPath = $backupfile;
			}
				

			return $SBA;
	}
}

