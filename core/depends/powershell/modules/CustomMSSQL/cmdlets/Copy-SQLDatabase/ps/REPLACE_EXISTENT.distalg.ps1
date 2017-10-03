#This algorithm distribute files in a round roubin manner.

param($files,$volumes)
Log "	replacExistentAlgorithm: Files will be putted on same existent filename"

$files | %{
	$currentFile = $_;
	Log "	File $($currentFile.logicalName). Size $($currentFile.size) bytes"
	
	#Get path for same file...
	$elegibleVolume = $volumes | where {$_.sqlLogicalName -eq $currentFile.logicalName};
	
	if(!$elegibleVolume){
		Log "		NO VOLUME FOUND. CHOOSING A RANDOM!"
		$elegibleVolume =  Get-Random -InputObject $volumes
	}
	
	#Check if a volume was returned
	if(!$elegibleVolume){
		#A volume was not found for restore the file... Throw a error...
		Log "		NO VOLUME FOUND!"
		throw "NO_VOLUME_FOUND_FOR_FILE"
	}
	
	$currentFile.restoreOn = [System.IO.Path]::GetDirectoryName($elegibleVolume.name);
	
	Log "		VOLUME FOUND: $($elegibleVolume.name). "
}