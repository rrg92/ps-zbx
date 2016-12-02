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
	,$AgentPort			= 10050
	,$InterfaceNetwork	= ""
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
		$Template = Get-ZabbixTemplate -Name $TemplateName;
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
		
		[hashtable[]]$Interfaces = @();
		
		
		
		
		if($currentSQL.Network.FullName -like '*.*'){
			$Interfaces = Get-InterfaceConfig -Address $CurrentSQL.Network.FullName -Port $AgentPort	
		} else {
			if($currentSQL.Network.IP){
				$IpCount = @($currentSQL.Network.IP).count
				
				if($IPCount -gt 1){
					
					$ElegibleIps = @();
					
					#Escolhe o IP conforme o parametro!
					$UserIpInfo = GetIpNetInfo $InterfaceNetwork
					
					$ElegibleIps  = $currentSQL.Network.IP | ? {
						$IpNet = $_.Ip+'/'+$_.Subnet;
						$NetWorkInfo = GetIpNetInfo $IpNet;
						
						return $NetworkInfo.NetworkIp -eq $UserIpInfo.NetworkIp;
					}
					
					$IpToUse = $ElegibleIps | Get-Random;
					$Interfaces = Get-InterfaceConfig -Address $IpToUse.IP -Port $AgentPort -IsIp
				} else {
					$Interfaces = Get-InterfaceConfig -Address $CurrentSQL.Network.IP[0].IP -Port $AgentPort -IsIp
				}
				
				
			} else {
				write-host '	Sem configuração de ip para interface';
				return;
			}
		}
		



		try {
			$hostId = Create-ZabbixHost -HostName $HostName -Interface $Interfaces -Groups $Groups -Templates $Template
			write-host "	Host id: $($hostId.hostids)"
		} catch {
			write-host "	Failed: $_"
		}
		
	}
}













