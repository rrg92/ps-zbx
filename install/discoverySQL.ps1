<#
	Identifica as inst�ncias SQL existentes em uma m�quina!!!
	Sera retornado um array de objetos representando cada instancia encontrada.
	Proprieades:
	
	ComputerName
		O nome do computador onde a instancia foi encontrada.
		
		
	ServerName
		O nome completo da instancia, como retornado em @@servername
	
	IsClustered
		Indica se a instancia � em cluster ou nao!
		
	InstanceName
		O nome da instancia
	
	ServiceName
		O nome do servi�o associado com a instancia!!
		
	Network
		Um objeto contendo as informacoes de conexao!
		Props:
			IP
				IP pelo qual a instancia responde
			DNS
				DNS pelo qual a instancia responde
	
	
	
#>
$ErrorActionPreference="stop";
$SourceComputer = $Env:ComputerName;

#VAri�vel que ir� guardar as defini��es!
$SQLInstances = @{}

#Obt�m os servi�os que podem ser de inst�ncia SQL!
$SQLServices = @(Get-Service 'mssql$*' -EA "SilentlyContinue") + @(Get-Service "mssqlserver" -EA "SilentlyContinue");

$SQLServices | %{

	$Service =  $_.Name;
	
	$InstanceName = $_.name -replace 'mssql\$','';
	
	$SQLInstances.add($InstanceName,(New-Object PSObject -Prop @{
													ComputerName = $Env:ComputerName
													ServerName = $null
													IsClustered = $false
													InstanceName = $InstanceName
													ServiceName = $_.Name
													Network = (New-Object PSObject -Prop @{IP=$null;DNS=$SourceComputer;Domain=$null;FullName=$null})
													
												}));
}


#Verifica se h� SQL em cluster...
if(Get-Module -ListAvailable FailoverClusters ) {
	import-module FailoverClusters;
	
	#Verifica se no cluster atual h� um recursos do tipo 'SQL Server'
	if(Get-Cluster | Get-ClusterResourceType -Name 'SQL Server'){
		
		#Obt�m todos os recursos do tipo 'SQL Server'
		$SQLResources = Get-Cluster | Get-ClusterResource | ? {$_.ResourceType -eq 'SQL Server'};
		
		#Para cada recurso obt�m os par�metros...
		$SQLResources | %{
			$CurrentResource = $_;
			$Params = $CurrentResource | Get-ClusterParameter;
			$ParamInstanceName = ($Params | ? {$_.Name -eq "InstanceName"}).Value;
			$InstanceInfo = $SQLInstances[$ParamInstanceName];
			$InstanceInfo.IsClustered=$true;
			
			#Obt�m as configura��es de rede do grupo...
			$NetworkResource = $_.OwnerGroup | Get-ClusterResource | ? {$_.ResourceType -eq 'Network Name'}
			$DNSName		= $NetworkResource | ? {$_.Name -eq 'DNSName'}
			
			$NetworkResource = $_.OwnerGroup | Get-ClusterResource | ? {$_.ResourceType -eq 'Network Name'}
			$DNSName		= ($NetworkResource | Get-ClusterParameter | ? {$_.Name -eq 'DNSName'} | Get-Random).Value;
			$DNsSuffix		= ($NetworkResource | Get-ClusterParameter | ? {$_.Name -eq 'DnsSuffix'} | Get-Random).Value;
			
			$IPResource = $_.OwnerGroup | Get-ClusterResource | ? {$_.ResourceType -eq 'Ip Address'}
			$IPAddress	= ($IPResource | Get-ClusterParameter | ? {$_.Name -eq 'Address'} | Get-Random ).Value;
			
			$InstanceInfo.Network.IP 	= $IPAddress
			$InstanceInfo.Network.DNS 	= $DNSName
			$InstanceInfo.Network.Domain 	= $DNsSuffix	
		}
		
	}
	

}

#Obt�m as informa��es de dom�nio para configurar as instancias que n�o est�o em cluster...

$ComputerInfo = Get-WMIObject Win32_ComputerSystem
$ComputerDomain = $null;
if($ComputerInfo.partofdomain){
	$ComputerDomain = $ComputerInfo.domain;
}

#Obt�m todos os IPs e rede na m�quina!
#Cada posicao representa um objeto contendo as propriedades IP e Subnet
$AdaptersConfigurations = Get-WMIObject Win32_NetworkAdapterConfiguration | ?{$_.IpAddress};
$AllIps=@()

#Para cada configuration...
$AdaptersConfigurations | %{
	$CurrentAdapter = $_;
	
	$i = -1;
	$CurrentAdapter.IpAddress | %{ #Para cada ip no adapter...
		$CurrentIPs = $_;
		
		$i++;
		if($_ -like "*:*"){
			return; #Ingora o IPV6...
		}
		
		$CurrentIP 	= $_;
		$IpSubNet	= $CurrentAdapter.IpSubNet[$i];
		
		$Ip = New-Object PSObject -Prop @{IP=$CurrentIP;Subnet=$IpSubNet};
		$AllIps += $IP;
	}
}

#Para as inst�ncias que n�o est�o em cluster...
$SQLInstances.GetEnumerator() | ? { !$_.Value.IsClustered } | %{
	$SQLInstance = $_.Value;
	$SQLInstance.Network.Domain = $ComputerDomain;
	$SQLInstance.Network.IP = $AllIps;
}

$AllObjects = @();
$SQLInstances.GetEnumerator() | %{
	
	$CurrentO = $_.Value;
	$LeftName = $CurrentO.Network.DNS;
	
	
	if(!$LeftName){
		$LeftName = $CurrentO.Network.IP;
	}
	
	$LeftName += '\' + $CurrentO.InstanceName;
	$CurrentO.ServerName = $LeftName;
	
	$CurrentO.Network.FullName = $CurrentO.Network.DNS
	
	if($CurrentO.Network.Domain){
		$CurrentO.Network.FullName += '.' + $CurrentO.Network.Domain
	}
	
	
	$AllObjects += $_.Value;
}

return $AllObjects;