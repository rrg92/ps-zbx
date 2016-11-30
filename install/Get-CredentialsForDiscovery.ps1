#Utilidades gerais...

#Permite o usuário inserir credenciais para os servidores...
#Retorna uma hashtable contendo os pares de servidores/credenciais...


$Creds = @{};

Function ShowCredentials {
	param([switch]$NewScreen)
	
	if($NewScreen){
		Clear-Host
	}
	
	write-host 'Total de credenciais fornecidas: ' ($Creds.count);
	
	
	$out = @(
				$Creds.GetEnumerator() | select @{ N='ServerName';E={$_.Key} } `
										,@{ N='UserName';E={$_.Value.GetNetworkCredential().UserName} } `
										,@{ N='Password';E={$_.Value.GetNetworkCredential().Password} } `
			)
	
	$out  | %{
		write-host $_;
	}
	
	if($NewScreen){
		Read-Host 'ENTER para voltar...' | out-Null;
	}
	
}

Function GetUserOption {
	Clear-host | out-null
	ShowCredentials
	$Linha = Read-Host "Digite o nome do servidor"
	
	if($Linha.Length -eq 0){
		return $false;
	} else {
		return $Linha;
	}
}


while($serverName = GetUserOption){
	write-host "server name is" "$servername"
	
	if(!$ServerName){
		break;
	}

	if($Creds.Contains($ServerName)){
		write-host 'O Server que você forneceu já existe. Ignorando!';
		read-host 'ENTER para continuar' | out-null
		continue;
	}
	
	write-host "Agora, forneça as credenciais!"
	$C = Get-Credential;
	
	$Creds.add($ServerName, $C);
}

ShowCredentials -NewScreen;
return $Creds;