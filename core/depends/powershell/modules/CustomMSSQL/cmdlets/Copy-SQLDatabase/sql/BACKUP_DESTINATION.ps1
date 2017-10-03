#Determining options...
	$CopyOnly = ""
	if($DestMajorVersion -ge 9){ #If 2005 or high...
		$CopyOnly += ",COPY_ONLY"
	}
	
	$Compression = ""
	if($DestMajorVersion -ge 10){ #If 2008 or high
		$Compression += ",COMPRESSION"
	}
	
$BackupOptions = "$CopyOnly $Compression"
	

$BaseBackupCommand = 
"
	IF DB_ID('$DestinationDatabase') IS NULL 
	BEGIN	
		SELECT 'DontExists' as Status; 
		RETURN;
	END;
	
	EXEC('BACKUP DATABASE [$DestinationDatabase] TO DISK = ''$DestinationBackupPath'' WITH STATS = 10 $BackupOptions')
	SELECT 'Sucess!' Status 
"


return $BaseBackupCommand;