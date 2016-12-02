#Contém funções relacionadas a regras e interações com o SQL Server!


#Trata o nome da instância adequadamente para se adequar a certos valores que possam ser informados
#Por funções que capturam o nome da mesma 
Function PrepareServerInstanceString($ServerInstance){
	
	#Se a instância é nomeada e contém "MSSQLSERVER" como nome, então considera como instância default.
	if($Instance -like "*\MSSQLSERVER"){ 
		$InstanceName	= @($Instance -split "\\")[0]
	} else {
		#Se a instância contém "\" no nome, então troca a barra por "$"
		$InstanceName	= $Instance.replace("$","\"); 
	}
	
	return $InstanceName;
}