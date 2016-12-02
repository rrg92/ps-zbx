<#
	O mesmo que .config.ps1
	Porém, são configurações que são definidas somente em fase de desenvolvimento e o usuário não tem nenhum controle sobre elas.
	
	Todas essas configurações serão adicionadas a configuraçãoa atual e caso o usuário tenha definido algo, elas serão substituídas.
	Elas irão constar na hashtable de configuração do agente, sempre com um "_" antes.
 #>
 
$KEYSDEF_DIR = "\config\keys"
 
 
return @{ 

	#Keys groups mandatórios e de debug...
	_KEYS_GROUP = @{
		DEBUG = @(
			"\core\debug\keys\DebugKeys.keys.ps1"
		)
	}
	
	#Versão!
	_VERSION = "1.0"
	
}