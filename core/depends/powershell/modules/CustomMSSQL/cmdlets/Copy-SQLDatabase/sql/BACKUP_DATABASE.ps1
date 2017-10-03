param($VALUES)

if($VALUES.PARAMS.BackupTSQL){
	Log "	Was specified a T-SQL Backup command."
	return $VALUES.PARAMS.BackupTSQL;
}

$ServerInfoCommand = . $VALUES.SCRIPT_STORE.SQL.GET_INSTANCE_INFO $VALUES

Log "	Getting source SQL info"
Log "	Source Info Command: $ServerInfoCommand"
$SourceSQLInfo 	= . $SQLInterface.cmdexec -S $VALUES.PARAMS.SourceServerInstance -D master -Q $ServerInfoCommand
$SrcVersion		=  GetProductVersionNumeric $SourceSQLInfo.ProductVersion;

Log "	Source Server Version is: $SrcVersion"

$TSQL_Compression = ",COMPRESSION"

if($SrcVersion -lt 10){
	Log "	COMPRESSION unsupported!"
	$TSQL_Compression = ""
}

$TSQL_CopyOnly = ",COPY_ONLY"

if($SrcVersion -le 8){
	Log "	COPY_ONLY unsupported!"
	$TSQL_CopyOnly = ""
}

$BackupFolder 	= (PutFolderSlash $VALUES.PARAMS.BackupFolder);
$UniqueBackupName = $VALUES.PARAMS.UniqueBackupName;

if($UniqueBackupName){
	$ts = (Get-Date).toString("yyyy-MM-dd-HHmmss");
	$BackupFileName = "$($VALUES.BACKUP_FILEPREFIX).$ts.$($VALUES.BACKUP_FILESUFFIX)"
} else {
	$BackupFileName = "$($VALUES.BACKUP_FILEPREFIX).$($VALUES.BACKUP_FILESUFFIX)"
}

$FullDestinationPath = $BackupFolder+$BackupFileName
Log "		Destination backup file will be: $FullDestinationPath"

$BackupCommand = "
	BACKUP DATABASE
		[$SourceDatabase]
	TO	
		DISK = '$FullDestinationPath'
	WITH
		STATS = 10
		$TSQL_CopyOnly 
		$TSQL_Compression
		,INIT
		,FORMAT
		
	SELECT '$FullDestinationPath' as backupfile;
"

return $BackupCommand;