#Check if a file can be accessed by specific lock type.
#You can test for S, or X.
#Based on http://stackoverflow.com/questions/876473/is-there-a-way-to-check-if-a-file-is-in-use

Function GetFileLockStatus {
	param($FileName,$AccessType = "X",[switch]$KeepOpen=$false)

	$r = New-Object PSObject -Prop @{
								locked=$null
								stream=$null
								lockType=$null
							}
	
	$FileShare = "None";
	switch($AccessType){
		default {
			throw "INVALID_ACCESS_TYPE: $AccessType";
			return;
		}
	}
	
	$r.lockType = $AccessType;
	
	if(!(Test-Path $FileName)){
		throw "INVALID_FILENAME"
		return;
	}

	$opened = $false;
	
    try {
		$fileinfo = [System.IO.FileInfo] $FileName
        $r.stream = $fileInfo.Open("Open","Read","Read")
		$opened = $true;
		$r.locked = $false;
		
		if($AccessType -eq  "X"){
			try {
				$lockingRes = SetFileLocking -Stream $r.stream -X;
				
				if(!$lockingRes){
					throw "CANNOT_X_LOCK"
				}
				
			} catch {
				$KeepOpen = $false;
				throw "ERROR_X_LOCKING: $_";
			}
		}
    } catch  {
       if(!$opened){
			throw New-Object System.Exception("CANNOT_S_LOCK")
	   }
    } finally {
	
		if($opened -and !$KeepOpen){
			 $r.stream.Dispose() | Out-Null
			 $r.stream = $null;
		}
	
	}
	


    return $r
}

#Try lock a file by a specific type.
#The sleep time specifies the time the functions will wait to file unlock.
#The attempt timeout specifies amount of milliseconds the function will try lock the file.
Function LockFile {
	param($File,$AccessType = "S", $SleepTime = 1000, $Timeout = 0)
	
	$StartTime = Get-Date;
	$EffectiveSleepTime = 0;
	$handle = New-Object PSObject -Prop @{lockStatus=$null;timedOut=$false};
	$firstTime = $true;
	
	do {
		
		if($firstTime){ #if first time.
			$firstTime = $false;
		} else {
			Start-Sleep -M $SleepTime;
		}
		
		$handle.lockStatus = GetFileLockStatus -FileName $File -AccessType $AccessType -KeepOpen
		
		if(!$handle.lockStatus.locked){
			return $handle;
		}
		
	} while( ((Get-Date)-$StartTime).totalMilliseconds -le $Timeout -or $Timeout -eq -1 )
	
	$handle.timedOut = $true;

	return $handle;
}

Function UnLockFile {
	param($Handle)


	if($Handle.lockStatus.stream){
		$Handle.lockStatus.stream.Dispose();
		return $true;
	}
		
	return $false;
}

Function SetFileLocking {
	param($stream,[switch]$S = $false,[switch]$X = $false)
	
	if(!$stream){
		throw "INVALID_STREAM";
	}
	
	if($S){
		$stream.UnLock(0,$stream.Length);
		return $true;
	}
	
	if($X){
		$stream.Lock(0,$stream.Length)
		return $true;
	}
	
	return $false;
}

Function ChangeFileLockType {
	param($Handle,$Type)
	
	$Action = "UnLock";

	if($Type = "S"){
		#Try UnLockFile...
		
		if($Handle.lockType -eq "X"){
			try {
				SetFileLocking -Stream $handle.lockStatus.stream -UnLock;
			} catch {
				throw "ERROR_UNLOCKING_FILE: $_";
				return $false;
			}
		}
	}
	
	if($Type = "X"){
		#Try Lock file...
		
		if($Handle.lockType -eq "S"){
			try {
				SetFileLocking -Stream $handle.lockStatus.stream;
			} catch {
				throw "ERROR_LOCKING_FILE: $_";
				return $false;
			}
		}
	}
	
	
	
	$s.lockType = $Type;
	return $true;
}