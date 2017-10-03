param($VALUES)

Log "	Getting destination database files!"

#File command!
$GetFilesCommand = . $VALUES.SCRIPT_STORE.SQL.GET_DATABASE_FILES

Log "		GET_DATABASE_FILES Command: $BACKUPCOMMAND";

$VALUES.DESTINATION_INFO.DestinationFiles = . $SQLInterface.cmdexec -S $VALUES.PARAMS.DestinationServerInstance -d $VALUES.PARAMS.DestinationDatabase -Q $GetFilesCommand