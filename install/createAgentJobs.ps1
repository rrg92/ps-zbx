#Cria os jobs SQL...
param(
	$DiscoveredSQL
	,$SQLCreds = $null
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
	$LogScript 	= $LogDir + '\CreateSQLJob_'  + ($SQLInstance.replace('\','$')) + '.script.sql'
	
	if($Creds){
		$SQLAuth.Login = $Creds.GetNetworkCredentials().UserName
		$SQLAuth.Password = $Creds.GetNetworkCredentials().Password
		
		write-host "Usando as credenciais diferentes: $($SQLAuth.Login)" >> $LogFile 
	}
	

	$SQLJobDefault = Get-Content (GetInstallMSSQLScript 'jobs\JOBZabbixDefault.sql');
	$Vars = @{
		JobName 	= 'DBA: MON DEFAULT' 
		BaseDir		= $BaseDir
		AgentName	= 'DEFAULT.ps1'
		KeysGroup	= 'DEFAULT'
	}
	$SQLScript = ReplaceSQLPsZbxVar -SQLScript $SQLJobDefault -Vars $Vars;
	$SQLScript > $LogScript;
	
	
	try {
		write-host "Criando jobs default em $SQLInstance...";
		$resultados = Invoke-NewQuery -ServerInstance $SQLInstance -Logon $SQLAuth -Query ($SQLScript -Join "`r`n")  -Database 'msdb'
		$resultados >> $LogFile;
	} catch {
		"Falha ao criar o job $($Vars.JobName): Crie manualmente depois!. Error: $SQLError" >> $LogFile;

		$SQLError = FormatSQLErrors $_.Exception;
		$SQLError >> $LogFile
		write-host "	Falha! Verifique os logs!"
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
