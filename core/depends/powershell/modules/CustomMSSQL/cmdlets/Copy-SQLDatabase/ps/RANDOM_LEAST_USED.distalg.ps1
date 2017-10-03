#This algorithm distribute files in a round roubin manner.
param($files,$volumes)

Log "	randomLeastUsed: Files will be distributed randomically"

$volumes | Add-Member -Type Noteproperty -Name UsedCount -Value 0

$files | %{
	$currentFile = $_;
	Log "	File $($currentFile.logicalName). Size $($currentFile.size) bytes"
	
	#get the least used volume...
	$elegibleVolume = $volumes | sort UsedCount | select -First 1;
	
	#Check if a volume was returned
	if(!$elegibleVolume){
		#A volume was not found for restore the file... Throw a error...
		Log "		NO VOLUME FOUND!"
		throw "NO_VOLUME_FOUND_FOR_FILE"
	}
	
	$elegibleVolume.UsedCount++;
	$currentFile.restoreOn = $elegibleVolume.name;

	Log "		VOLUME FOUND: $($elegibleVolume.name). Used count: $($elegibleVolume.UsedCount) "
}