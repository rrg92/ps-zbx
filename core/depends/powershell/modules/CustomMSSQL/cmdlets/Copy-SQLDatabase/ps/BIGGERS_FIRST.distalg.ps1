#This algorithm distribute big files first. It get bigger file and choose the volume with more 
# free space and decrements volume free space by size of file.
param($files,$volumes)

Log "	biggersFirst: Bigger files are mapped first!"

#$files must be a array of objects. Properties expeted:  size (bytes), restoreOn, name (logical name of file)
#$volumes must be a array of objects. Properties expected:  freeSpace (bytes), name (path to volume)


$files | sort size -Desc | %{
	$currentFile = $_;
	Log "	File $($currentFile.logicalName). Size $($currentFile.size) bytes"
	
	#get all volumes which free space is bigger than size of file and file is alloed on volume. Then, gets the volume with more free space.
	Log "		Eligibling a volume..."
	$eligibleVolume = $volumes | where {
									$VALIDATIONS = @{
										HAVE_SPACE = $_.freeSpace -ge $currentFile.size;
										IS_ALLOWED = $_.isFileAllowed($currentFile);
									}
									
									[bool]$result = $true;
									$logResult = @()
									$VALIDATIONS.GetEnumerator() | %{
										$result = $result -band ([bool]$_.Value);
										$logResult += "$($_.Key): $($_.Value)"
									}
	
								$validationsResultText = $logResult -join " | "
								Log "			VOLUME: $($_.name) [$result] --> $validationsResultText"
								return $result;
					} | sort freeSpace -Desc | select -First 1;
	
	#Check if a volume was returned
	if(!$eligibleVolume){
		#A volume was not found for restore the file... Throw a error...
		Log "		NO VOLUME FOUND!"
		throw "NO_VOLUME_FOUND_FOR_FILE"
	}
	

	$eligibleVolume.freeSpace -= $currentFile.size
	$currentFile.restoreOn = $eligibleVolume.name;

	Log "			ELIGIBLE: $($eligibleVolume.name). Left Space: $($eligibleVolume.freeSpace) "
}
				