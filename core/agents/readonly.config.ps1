<#
	O mesmo que .config.ps1
	Por�m, s�o configura��es que s�o definidas somente em fase de desenvolvimento e o usu�rio n�o tem nenhum controle sobre elas.
	
	Todas essas configura��es ser�o adicionadas a configura��oa atual e caso o usu�rio tenha definido algo, elas ser�o substitu�das.
	Elas ir�o constar na hashtable de configura��o do agente, sempre com um "_" antes.
 #>
 
$KEYSDEF_DIR = "\config\keys"
 
 
return @{ 

	#Keys groups mandat�rios e de debug...
	_KEYS_GROUP = @{
		DEBUG = @(
			"\core\debug\keys\DebugKeys.keys.ps1"
		)
	}
	
	#Vers�o!
	_VERSION = "1.0"
	
}