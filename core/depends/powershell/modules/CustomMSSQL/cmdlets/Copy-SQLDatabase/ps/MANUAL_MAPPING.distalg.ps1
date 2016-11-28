#This algorithm apply manual file mapping.
param($files,$volumes)
Log "	manualMapping: The specified mapping will be used with no handling by script"

$files | %{
	$currentFile = $_;
	Log "	File $($currentFile.logicalName). Size $($currentFile.size) bytes"
	
	#Get path for same file...
	$elegibleVolume = $volumes | where {$_.sqlLogicalName -eq $currentFile.logicalName};
	
	#Check if a volume was returned
	if(!$elegibleVolume){
		#A volume was not found for restore the file... Throw a error...
		Log "		NO VOLUME FOUND!"
		throw "NO_VOLUME_FOUND_FOR_FILE"
	}
	
	$currentFile.restoreOn = $elegibleVolume.name;
	$currentFile.PathIsComplete = $true;
	
	Log "		VOLUME FOUND: $($elegibleVolume.name). "
}