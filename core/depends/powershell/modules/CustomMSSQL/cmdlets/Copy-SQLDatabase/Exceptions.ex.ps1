#Exceptions table.
#Hash table containing exceptions text and descriptions. The description can include formating characteres.
#Decriptions will be used for more detailied message.
#Each key of table is a exception code. It must be in format "EXCEPTION_NAME" (Upper case and words separated by _)

@{
	POST_SCRIPT_ERROR = "The previous executed post script presented errors. Check previous messages"
	NO_VOLUMES_AVAILABLE = "No volumes all available to put files. Check permissions on destination computer or if filtering is removing all avaliable volumes."
	NO_EXISTENT_BACKUP_NAME_FOUND = "No backup existent backup was found. Check ExistentPolicy choosed."
	NO_VOLUME_FOUND_FOR_FILE = "No elegible volume was found for file. Check previous messages to determine the file."
	NO_RECENT_BACKUP_FOUND = "No backup existent backup was found. Check ExistentPolicy choosed."
	MSSQL_ERRORS_CHECK_PREVIOUS_ERRORS = "Error ocurred when executing some query script. Check previous messages to more errors information."
	NO_DFA = "No distribute file algorithm found. Check DFA files exists in correct expected folder and filename matchs the filter specified."
	MULTIPLE_MAPPED_FOLDERS = "A same volume have multiple mapped folders. Check corresponding parameters. A LUN must be mapped to single folder when using VolumeToFolder feature."
}