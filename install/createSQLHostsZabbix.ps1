param(
	 $ZabbixURL		= $null
	,$User 			= $null
	,$Password 		= $null
	,$Source  		= "ServerList"
	,$SourceContent	= $null
	,$ServerCreds	= @()
	,[switch]$DiscoveryOnly = $false
	,$TemplateName 		= "SQL Server"
	,$ZabbixGroups
	,$HostNamePrefix	= ""
	,$VisibleNamePrefix	= ""
)
<#
	Descobre os hosts SQL para serem criados no zabbix!
#>

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
	ImportPowershellModules 'power-zabbix'
	
#Configura o diretorio de log!
	$InstallLogDir = (GetDefaultLogDir) + '\log\install';
	[void](mkdir $InstallLogDir -force);
	$LogFile = $InstallLogDir + '\lastinstall.log'

$DiscoveredSQL 	= @();

switch ($Source){
	
	"ServerList" {
		#Conecta na lista de servers informados tentando descobrir as isntancias SQL...
		if($SourceContent.count -gt 1){
			$Servers = $SourceContent
		} else {
			if([System.IO.File]::Exists($SourceContent)){
				$Servers = Get-Content $SourceContent
			} else {
				$Servers = $SourceContent
			}
		}
		
		$ErrorLogFile = GetLogFileName -Dir $InstallLogDir -Prefix 'DiscoverySQL-ServerListSource'
		$DiscoveryScript = $BaseDir + '\install\discoverySQL.ps1';
		$Servers | %{
			$server = $_;
			
			if( @($Env:ComputerName,'.') -Contains $server ){
				$server = "localhost"
			}
			
			write-host "Conectando em $_..."
			
			try {
				$InvokeCommandParams = @{
						ComputerName = $_
						FilePath = $DiscoveryScript
					}
					
				if( $ServerCreds ){
					$CredToUse = ($ServerCreds.GetEnumerator() | ? { $server -like $_.Key } | select -first 1);
					
					if($CredToUse){
						write-host "Using credential for $($CredToUse.Key)";
						$InvokeCommandParams.add("Credential",$CredToUse.Value);
					}
				}
			
				if($Server  -eq "localhost"){
					$DiscoveredSQL += & $DiscoveryScript;
				} else {
					$DiscoveredSQL += Invoke-Command @InvokeCommandParams
				}
			

				
			} catch {
				write-host '	Falhou!'.
				"ServerListSourceError: $server $_" >> $ErrorLogFile;
			}
			
		}
		
		$DiscoveredSQL = $DiscoveredSQL | sort ServerName -Unique
				

		if($DiscoveryOnly){
			return $DiscoveredSQL 
		}
	}

	"Existent" {
		write-host "Using existents... "
		$DiscoveredSQL = $SourceContent
	}
	
}





if($DiscoveredSQL){
	write-host "discovered SQL: $($DiscoveredSQL.count)"

	#Para cada SQL que foi identificado, cria os dados no Zabbix!
	Set-ZabbixConnection -url $ZabbixURL;
	write-host "Autenticando no zabbix em $Zabbixurl"
	Auth-Zabbix -User $User -Password -$Password;

	if($TemplateName){
		$Template = Get-ZabbixTemplates -Name $TemplateName;
		if(!$Template){
			throw 'NO_TEMPLATE_FOUND: $Template';
		}
	}

	$Groups = Get-ZabbixHostGroup -Name $ZabbixGroups

	if(!$Groups){
		throw 'NOT_GROUP_FOUND: $ZabbixGroups'
	}
	
	$DiscoveredSQL  | %{
		$currentSQl = $_;
		write-host "Creating zabbix host for $($currentSQl.ServerName)"
	
		$HostName = $currentSQl.ServerName.replace("\"," ");
		
		if($HostNamePrefix){
			$HostName = "$HostNamePrefix $HostName";
		}
		
		$InterfaceConfig = @{type=1;main=1;useip=0;ip="";dns="";port=10050}
		
		if($currentSQL.Network.DNS){
			$InterfaceConfig.dns = $CurrentSQL.Network.DNS
		} else {
			$InterfaceConfig.useip = 1;
			$InterfaceConfig.ip = $CurrentSQL.Network.IP
		}

		try {
			$hostId = Create-ZabbixHost -HostName $HostName -Interface $InterfaceConfig -Groups $Groups -Templates $Template
			write-host "	Host id: $($hostId.hostids)"
		} catch {
			write-host "	Failed: $_"
		}
		
	}
}













