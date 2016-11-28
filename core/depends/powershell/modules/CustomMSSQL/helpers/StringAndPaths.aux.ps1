Function Right($str,$qtd = 1){
	return $str.substring($str.length - $qtd, $qtd)
}

Function PutFolderSlash($folder, [switch]$Slash = $false ){
	if(!$folder){return $null}
	
	$slashToUse = '\'
	$slashToReplace = '/'
	if($Slash){
		$slashToUse = '/'
		$slashToReplace = '\'
	}
	
	write-verbose "Current folder: $folder"
	$folder = $folder.replace($slashToReplace,$slashToUse)

	if( (Right($folder)) -ne $slashToUse ){
		$folder += $slashToUse
	}

	return $folder
}

Function IsDirectory {
	param($Path)
	
	$attrs = [System.IO.File]::GetAttributes($Path);
	$dirattr = [System.IO.FileAttributes]::Directory
	return (($attrs -band $dirattr) -eq $dirattr) -as [bool]
}
