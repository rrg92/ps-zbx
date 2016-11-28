param($Source = "DATABASE_FILES")

#Possible sources: DATABASE_FILES,BACKUP_FILE


#Build T-SQL command to retrieve backup files based on $source variable!
[string]$BACKUPCOMMAND = "";

switch ($source){

	"DATABASE_FILES" {
		$BACKUPCOMMAND = "
			SELECT 
				 F.file_id as FileID 
				,F.name as logicalName
				,F.physical_name AS physicalName 
				,CASE F.Type
					WHEN 0 THEN 'D'
					WHEN 1 THEN 'L'
					WHEN 2 THEN 'S'
				END as Type
				,F.size as Size
			FROM 
				sys.database_files F
		"
	}
	
	"BACKUP_FILE" {
		$BACKUPCOMMAND = "
			RESTORE FILELISTONLY
			FROM 
				DISK = '$($VALUES.SOURCE_BACKUP.originalFullPath)'
		"
	}
	
	default {
		throw "INVALID_SOURCE: $Source. This can be a bug on Copy-SQLDatabase cmdlet. Contact the developer!";
	}

}

if(!$BACKUPCOMMAND){
	throw "INVALID_BACKUP_COMMAND! ITS IS EMPTY! THIS IS A BUG ON Copy-SQLDatabase cmdlet. Contact developer!"
}

return $BACKUPCOMMAND;