#Cria os jobs SQL...
param(
	$DiscoveredSQL
	,$SQLCreds = $null
	,$ConfigurationFile = $null
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
	$LogDir = GetLogFileName -Dir ( (GetDefaultLogDir) + '\install\mssql\jobs') -AsDir
	
write-host "Logando em  $LogDir";

Function CreateSQLJobs {
	param($SQLInstance, $BaseDir, $Creds)

	$SQLAuth = @{
		AuthType="Windows";
		Login="";
		Password="";
	}
	
	$LogFile 	= $LogDir + '\CreateSQLJob_'  + ($SQLInstance.replace('\','$')) + '.log'
	
	if($Creds){
		$SQLAuth.Login = $Creds.GetNetworkCredentials().UserName
		$SQLAuth.Password = $Creds.GetNetworkCredentials().Password
		
		write-host "Usando as credenciais diferentes: $($SQLAuth.Login)" >> $LogFile 
	}
	
	$JobsToCreate = @{
		DEFAULT = @{
			JobName 	= 'DBA: MON ZABBIX DEFAULT' 
			BaseDir		= $BaseDir
			AgentName	= 'DEFAULT.ps1'
			KeysGroup	= 'DEFAULT'
			PoolingTime = 60000
			ConfigurationFile = $ConfigurationFile
		}
			
		DISCOVERY = @{
			JobName 	= 'DBA: MON ZABBIX DISCOVERY' 
			BaseDir		= $BaseDir
			AgentName	= 'DEFAULT.ps1'
			KeysGroup	= 'DISCOVERY'
			PoolingTime = 0
			JobFreqMin	= 15
			ConfigurationFile = $ConfigurationFile
		}
	}
	
	$JOBTemplate = Get-Content (GetInstallMSSQLScript 'jobs\JOBTemplate.sql');
	
	$JobsToCreate.GetEnumerator() | %{
		$Name = $_.Key;
		$Vars = $_.Value;
		$LogScript = $LogDir + '\CreateSQLJob_'  + ($SQLInstance.replace('\','$')) + ".$Name.script.sql"
		
		write-host "Attempting create job: $Name";
		
		try {
			$SQLScript = ReplaceSQLTemplateParameters -SQLScript $JOBTemplate -Vars $Vars -Force;
			$SQLScript > $LogScript;
			write-host "Criando job  $Name em $SQLInstance...";
			$resultados = Invoke-NewQuery -ServerInstance $SQLInstance -Logon $SQLAuth -Query ($SQLScript -Join "`r`n")  -Database 'msdb';
			$resultados >> $LogFile;
		} catch {
			$SQLError = FormatSQLErrors $_.Exception;
			"Falha ao criar o job $Name : Crie manualmente depois!." >> $LogFile;
			$SQLError >> $LogFile
			write-host "	Falha! Verifique os logs!"
		}
		
	}	
	
}

$DiscoveredSQL | %{

	$currentSQl = $_;
	
	$SQLConnectionName = $CurrentSQL.Network.DNS
	
	if(!$currentSQl.IsDefault){
		$SQLConnectionName  += '\' + $CurrentSQL.InstanceName;
	}
	
	$SQLCred = $null;
	if($SQLCreds){
		$SQLCreds.GetEnummerator() | ?{!$SQLCred} | %{
			if($CurrentSQL.ServerName -like $_.Key){
				$SQLCred = $_.Value;
				return;
			}
		}
	}
	

	
	try {
		CreateSQLJobs -SQLInstance $SQLConnectionName -BaseDir $BaseDir  -Creds $SQLCred
	} catch {
		write-host "	Error: $_";
	}


}
