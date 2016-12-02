<#
	Este arquivo define certos par�metros de configura��o do agente DEFAULT.
	As configura��es s�o definidas como itens de uma hashtable.
	O agente ir� carregar este arquivo, que dever� retornar uma hashtable com as configura��es.
	
	A documenta��o de cada configura��o est� descrita abaixo. Utilize este arquivo como um modelo para implementar agentes customizados.

	Items de configura��o que representam caminhos de arquivos ou diretorio podem iniciar com "/".
	Quando um item desse tipo iniciar com "/", significa um caminho relativo para o diretorio raiz onde os scripts foram instalados.
	Por exemplo, se a solu��o foi instalada em "C:\Zabbix\SQLZBX" e o item especifica "\config\keys", ent�o o caminho completo � "C:\Zabbix\SQLZBX\config\keys".
 #>
 

#Vamos definir alguns valores usados em v�rios locais:
	$KEYSDEF_DIR = "\config\keys"
 

return @{
	
	#Diret�rio onde se encontram as keys (Arquivos keysdef.ps1)
	KEYSDEF_DIR = $KEYSDEF_DIR
	
	#Diret�rios com os scripts que ser�o executados para gerar os dados.
	SCRIPTS_DIR	= "\config\scripts"
	
	#Caminho para o m�dulo CustomMSSQL (M�dulo importante para o funcionamento da solu��o)
	CUSTOMMSSQL_PATH = "\core\depends\powershell\modules\CustomMSSQL"
	
	#Diretorio de log. Este sera o local padr�o onde os logs dos scripts ser�o feitos.
	LOGBASE_DIR	= "\log"
	
	
	#Endere�o e porta do zabbix
	ZABBIX_SERVERPORT	 = "localhost:10051"
	
	#Diret�rio com o zabbix_sender.exe .Utilize a versao mais recente e suportada pela solu��o.
	#Por padr�o, a solu��o inclui uma vers�o, mas n�o impede do usu�rio especificar o caminho com uma solu��o mais recente.
	ZABBIXSENDER_PATH = "\core\depends\tools\zabbix_sender.exe"
	
	#Script usado para determinar o hostname a ser enviado para o zabbix.
	#Este script � util quando o hostname diferene do nome da instancia enviado.
	#O par�metro $VALUES cont�m valores �teis que podem ser usados para auxiliar.
	#Para saber que valores estao disponiveis, consulte o script do agente!
	DYNAMIC_HOSTNAME_SCRIPT = {
			param($VALUES)
			
			write-host "abc"
			
		}
		
	#Este item define grupos de keys.
	#Os grupos de keys s�o �teis e permitem especificar v�rias keys baseados em um grupo.
	#O script do agente aceita um par�metro chamado "KeysGroup". Ao especificar este par�metro, o script ir� usar as keys definidas
	#neste item.
	KEYS_GROUP = @{}
}






















