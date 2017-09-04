#Replica o diretorio config para outros diretorios de instalacao do pszbx!
param(
	
	#Source directory where exist a "config" subdirectory.
	$Source
	
	
	,#Specify the copy paths. For example,  \\server1\c$\zabbix\pszbx
	#You can use the ZabbixServers and installPath to get more control over.
		$CopyPaths = $null
	
	,#Array of servers to copy. It will be copied via a admin share, based on InstallPath.
	#For example, if servers is SERVER1, SERVER2 and InstallPath is C:\Zabbix\pszbx, then it will copy to
	#\\SERVER1\c$\zabbix\pszbx and \\SERVER2\c$\zabbix\pszbx
		$ServerNames = $null
	
	,#Specify the install path on the server to be used in conjunction the server names provided.
	 #It will be translated to a admin share.
		$InstallPath = 'C:\zabbix\pszbx'
		
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
	
if($CopyPaths){
	if([IO.File]::Exists($CopyPaths)){
		$CopyPaths = Get-Content $CopyPaths;
	}
}  else {
	
	if($ServerNames){
		if([IO.File]::Exists($ServerNames)){
			$ServerNames = Get-Content $ServerNames;
		}
	
		#Check if a valid install path was provided!
		if(!$InstallPath){
			throw "EMPTY_INSTALL_PATH";
		}
		
		#Build the copy paths!
		$CopyPaths = $ServerNames | %{  Local2RemoteAdmin -Path $InstallPath -RemoteAddress $_  -PreserveLocal  }
	}
	
}

if(!$CopyPaths){
	throw 'NO_COPY_PATH'
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
				
				copy -recurse "$CurrentPath\config" $BackupDir -force;
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