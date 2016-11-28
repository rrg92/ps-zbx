<#

	Este arquivo define certos par�metros de configura��o usados pelos agents.
	Ele define todas as propriedades que devem existir, sua documenta��o e seu valor padr�o.
	
	O usu�rio nunca deve alterar este arquivo que pode sofrer atualiza��es entre versoes.
	
	As configura��es s�o definidas como itens de uma hashtable.
	O agente ir� carregar este arquivo, que dever� retornar uma hashtable com as configura��es.
	
	Os valores definidos aqui s�o os padr�es. Se no arquivo de configura��o do diretorio \config\agents, o valor n�o estiver definido, este valor ser� usado.
	
	
	Caminhos de arquivos
		Items de configura��o que representam caminhos de arquivos ou diretorio podem iniciar com "\".
		Quando um item desse tipo iniciar com "\", significa um caminho relativo para o diretorio raiz onde os scripts foram instalados.
		Por exemplo, se a solu��o foi instalada em "C:\Zabbix\SQLZBX" e o item especifica "\config\keys", ent�o o caminho ser� expandido para "C:\Zabbix\SQLZBX\config\keys".
		
		A expans�o � recursiva, o que significa que se houver items cujo seu valor � uma outra hashtable, e algum ou todos filhos deste items s�o caminhos de arquivos, a expans�o ser� feitas nos mesmos tamb�m.
		
		Tamb�m se houver necessidade, items que aceitam array de valores, poder�o ser expandidos.
		N�o utilize nomes que iniciem com "_", pois estes s�o reservados e poder�o ter seu valor sobrescrito.
		
 #>
 

#Vamos definir alguns valores usados em v�rios locais.
#Isto s�o apenas vari�veis do powershell com valores que poderao ser usados em mais de um lugar nas configura��es abaixo.
#� �til para evitar rescrever valores.
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
			
			
			#Por padr�o, substitui a barra por um " ".
			#Se houver o nome mssqlserver depois da barra, retira ele.
			
			$Instance = $VALUES.Instance;
			
			if($Instance -like "*\MSSQLSERVER"){
				return $Instance.replace("\MSSQLSERVER","")
			} else {
				return $Instance.replace("\"," ");
			}
		}
		
	#Este item define grupos de keys.
	#Os grupos de keys s�o �teis e permitem especificar v�rias keys baseados em um grupo.
	#Ao executar o agente, o par�metro KeysGroup pode ser usado para especificar o grupo de keys a ser usado.
	#Isso permite adicionar e remove arquivos facilmente, sem a necessidade de mudar a linha de comando.
	#O usu�rio pode fornecer quandos grupos quiser.
	#O nome de cada grupo � definido como um item desta hashtable.
	#E o valor deste item � um array, onde cada item do array especifica um caminnho.
	KEYS_GROUP = @{}
		
	#Keygroup default! Este ser� usado quando n�o for especificado.
	DEFAULT_KEYS_GROUP = $null
}






















