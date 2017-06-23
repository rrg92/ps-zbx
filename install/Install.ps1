[CmdLetBinding()]
param(
	#Specify the copy paths. For example,  \\server1\c$\zabbix\pszbx
	#You can use the ZabbixServers and installPath to get more control over.
		$CopyPaths = $null

	,#Array of servers to copy. It will be copied via a admin share, based on InstallPath.
	#For example, if servers is SERVER1, SERVER2 and InstallPath is C:\Zabbix\pszbx, then it will copy to
	#\\SERVER1\c$\zabbix\pszbx and \\SERVER2\c$\zabbix\pszbx
		$ServerNames = $null
	
	,#Specify the install path on the server to be used in conjunction the server names provided.
	 #It will be translated to a admin share.
		$InstallPath = 'C:\zabbix\pszbx'
	
	,#The log level of progress of install...
		$LogLevel = "DETAILED"
)


#Diretórios que não devem ser copiados (contém dados do usuário)
$ErrorActionPreference="Stop";


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
		. $LoadLib $BaseDir 
	} catch {
		$ex = New-Object Exception("LIB_LOAD_FAILED", $_.Exception)
		throw $ex;
	}
	$DebugMode = $OriginalDebugMode;
	
#Dependencies...
	ImportPowershellModules 'XLogging';
	
#Configurando log...
	$Log = New-LogObject
	$Log.LogTo = @("#",$null)
	$Log.LogLevel = $LogLevel; 
	$Log.UseDLD = $false

	SetPsZbxVar 'INSTALL_LOG_OBJECT' $Log;
	
$Log | Invoke-Log "Processo de install iniciado!" "PROGRESS"
	
$InstallLogDir 	= GetInstallLogDir
$PathLog		= GetLogFileName -Prefix "PATHS" -Dir $InstallLogDir;


$Log | Invoke-Log "Diretorio de log: $InstallLogDir. Path id mapping: $PathLog" "PROGRESS"

if($CopyPaths){
	if([IO.File]::Exists($CopyPaths)){
		$CopyPaths = Get-Content $CopyPaths;
	}
} else {
	
	if($ServerNames){
		#Check if a valid install path was provided!
		if(!$InstallPath){
			throw "EMPTY_INSTALL_PATH";
		}
		
		#Build the copy paths!
		$CopyPaths = $ServerNames | %{  Local2RemoteAdmin -Path $InstallPath -RemoteAddress $_   }
	}
	
}

if(!$CopyPaths){
	throw 'NO_COPY_PATH'
}
	
$PathID = 0;
$CopyPaths | %{
	$PathID++;
	$CurrentPath = $_;
	"$PathID --> $_" >> $PathLog;
	
	$InstallLogFile = GetLogFileName -Prefix "InstallPath_$PathID" -Dir $InstallLogDir;
	$Log.LogTo[1] = $InstallLogFile;
	
	$Log | Invoke-Log "Installing on $_" "PROGRESS"

	try {
		#Verifica se no diretorio de destino existe uma estrutura com o diretorio core!
		$CorePath = $_ + '\core'
		
		if([System.IO.Directory]::Exists($CorePath)){
			$Log | Invoke-Log "Realizando upgrade..." "PROGRESS"
			Upgrade -DestBaseDir $_ -SourceBaseDir $BaseDir
		} else {
			$Log | Invoke-Log "instalando novo..." "PROGRESS"
			InstallSolution -DestinationBase $_ -SourceBaseDir $BaseDir
		}
	} catch {
		$Log | Invoke-Log "Error installing on $CurrentPath" "PROGRESS"
		$Log | Invoke-Log "$_" "PROGRESS"
	}
	


}

