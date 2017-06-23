#Replica o diretorio config para outros diretorios de instalacao do pszbx!
param(
	 $Source
	,$CopyPaths
	,$LogLevel = "DETAILED"
	,[switch]$NoValidateSource = $false
)

$ErrorActionPreference = "stop";
$CurrentFile = $MyInvocation.MyCommand.Definition
$CurrentDir  = [System.Io.Path]::GetDirectoryName($CurrentFile)
$BaseDir	 = [System.Io.Path]::GetDirectoryName($CurrentDir);

#Libs do componente de install. Note que estas libs são diferentes.
	$LibsDir = $BaseDir + "\core\glibs"
	
#Se não consegue encontrar o diretorio de libs...
	if(![System.IO.Directory]::Exists($LibsDir)){
		throw "LIB_DIR_NOT_FOUND: $LibsDir"
	}
	
#Carrega as libs 
	$OriginalDebugMode = $DebugMode;
	try {
		$LoadLib = $LibsDir + '\LoadLibs.ps1';
		. $LoadLib $BASEDIR 
	} catch {
		throw "LIBS_LOAD_FAILED: $_"
	}
	$DebugMode = $OriginalDebugMode;
	
#importa os módulos dependnetes!!!
	ImportPowershellModules 'CustomMSSQL'
	
	
#Determia o diretório de log...
	$LogDir = GetLogFileName -Dir ( (GetDefaultLogDir) + '\install\replicateConfig') -AsDir
	
	$Log = New-LogObject
	$Log.LogTo = @("#")
	$Log.LogLevel = $LogLevel; 
	$Log.UseDLD = $false
	$Log.IgnoreLogFail = $false
	
	SetPsZbxVar 'REPLICATE_CONFIG_LOGOBJECT' $Log;
	
if([IO.File]::Exists($CopyPaths)){
	$CopyPaths = Get-Content $CopyPaths;
}

$PathLog	= GetLogFileName -Prefix "PATHS" -Dir $LogDir ;

$Log | Invoke-Log "Determining source files..." "PROGRESS"

if(![IO.Directory]::Exists("$Source\config") -and !$NoValidateSource)  {
	throw "INVALID_SOURCE: $Source. Config directory not found!"
}

#Get the item that references directory!
$SourceConfigDirectory = Get-Item "$Source\config"



$PathID = 0;
$CopyPaths | %{
	$PathID++;
	$CurrentPath = $_;
	"$PathID --> $_" >> $PathLog;
	
	$PathLogFile = GetLogFileName -Prefix "ReplicateConfig_$PathID" -Dir $LogDir;
	
	if($Log.LogTo.count -eq 1){
		$Log.LogTo += $null;
	}
	
	$Log.LogTo[1] = $PathLogFile;
	
	$Log | Invoke-Log "Copy config to $CurrentPath..." "PROGRESS"
	
	try {
		if([IO.Directory]::Exists("$CurrentPath\config")){
			try {
				$BackupDir = GetReplicateConfigBackupDir -BaseDir $CurrentPath
				$Log | Invoke-Log " The destination config will be replaced. Backuping it! Backup dir is: $BackupDir" "PROGRESS"
				
				copy "$CurrentPath\config" $BackupDir -force;
			} catch {
				throw "BACKUP_FAILED: $_";
			}
		}

		#At this point, we backup. Just copy!
		$Log | Invoke-Log "Copying..." "PROGRESS"
		$SourceConfigDirectory  | copy -Destination $CurrentPath -force -recurse;

	} catch {
		$Log | Invoke-Log "Error replicating to $CurrentPath" "PROGRESS"
		$Log | Invoke-Log "$_" "PROGRESS"
	}
	


}