<#
	Este arquivo define certos parâmetros de configuração do agente DEFAULT.
	As configurações são definidas como itens de uma hashtable.
	O agente irá carregar este arquivo, que deverá retornar uma hashtable com as configurações.
	
	A documentação de cada configuração está descrita abaixo. Utilize este arquivo como um modelo para implementar agentes customizados.

	Items de configuração que representam caminhos de arquivos ou diretorio podem iniciar com "/".
	Quando um item desse tipo iniciar com "/", significa um caminho relativo para o diretorio raiz onde os scripts foram instalados.
	Por exemplo, se a solução foi instalada em "C:\Zabbix\SQLZBX" e o item especifica "\config\keys", então o caminho completo é "C:\Zabbix\SQLZBX\config\keys".
 #>
 

#Vamos definir alguns valores usados em vários locais:
	$KEYSDEF_DIR = "\config\keys"
 

return @{
	
	#Diretório onde se encontram as keys (Arquivos keysdef.ps1)
	KEYSDEF_DIR = $KEYSDEF_DIR
	
	#Diretórios com os scripts que serão executados para gerar os dados.
	SCRIPTS_DIR	= "\config\scripts"
	
	#Caminho para o módulo CustomMSSQL (Módulo importante para o funcionamento da solução)
	CUSTOMMSSQL_PATH = "\core\depends\powershell\modules\CustomMSSQL"
	
	#Diretorio de log. Este sera o local padrão onde os logs dos scripts serão feitos.
	LOGBASE_DIR	= "\log"
	
	
	#Endereço e porta do zabbix
	ZABBIX_SERVERPORT	 = "localhost:10051"
	
	#Diretório com o zabbix_sender.exe .Utilize a versao mais recente e suportada pela solução.
	#Por padrão, a solução inclui uma versão, mas não impede do usuário especificar o caminho com uma solução mais recente.
	ZABBIXSENDER_PATH = "\core\depends\tools\zabbix_sender.exe"
	
	#Script usado para determinar o hostname a ser enviado para o zabbix.
	#Este script é util quando o hostname diferene do nome da instancia enviado.
	#O parâmetro $VALUES contém valores úteis que podem ser usados para auxiliar.
	#Para saber que valores estao disponiveis, consulte o script do agente!
	DYNAMIC_HOSTNAME_SCRIPT = {
			param($VALUES)
			
			write-host "abc"
			
		}
		
	#Este item define grupos de keys.
	#Os grupos de keys são úteis e permitem especificar várias keys baseados em um grupo.
	#O script do agente aceita um parâmetro chamado "KeysGroup". Ao especificar este parâmetro, o script irá usar as keys definidas
	#neste item.
	KEYS_GROUP = @{}
}






















