#Cont�m fun��es relacionadas a regras e intera��es com o SQL Server!


#Trata o nome da inst�ncia adequadamente para se adequar a certos valores que possam ser informados
#Por fun��es que capturam o nome da mesma 
Function PrepareServerInstanceString($ServerInstance){
	
	#Se a inst�ncia � nomeada e cont�m "MSSQLSERVER" como nome, ent�o considera como inst�ncia default.
	if($Instance -like "*\MSSQLSERVER"){ 
		$InstanceName	= @($Instance -split "\\")[0]
	} else {
		#Se a inst�ncia cont�m "\" no nome, ent�o troca a barra por "$"
		$InstanceName	= $Instance.replace("$","\"); 
	}
	
	return $InstanceName;
}