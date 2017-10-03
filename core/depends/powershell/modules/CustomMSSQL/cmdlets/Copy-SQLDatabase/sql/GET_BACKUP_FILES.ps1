param($VALUES)

[string]$BACKUPCOMMAND = "";


#If in suggest mode -and file is present, then we must use originalPath... 
if($VALUES.PARAMS.SuggestOnly -and $VALUES.SOURCE_BACKUP.fullPath)
{
$BACKUPCOMMAND = "
	RESTORE FILELISTONLY 
	FROM 
		DISK = '$($VALUES.SOURCE_BACKUP.originalFullPath)'
"
}

elseif ($VALUES.PARAMS.SuggestOnly -and !$VALUES.SOURCE_BACKUP.fullPath -and $VALUES.SOURCE_BACKUP.algorithm -eq "S") #In this case, SQL will not execute backup command and we must return a SQL to query on source instance...
{
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
else 
{
$BACKUPCOMMAND = "
	RESTORE FILELISTONLY 
	FROM 
		DISK = '$($VALUES.SOURCE_BACKUP.fullPath)'
"
}




return $BACKUPCOMMAND;