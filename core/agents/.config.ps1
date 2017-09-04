<#

	Este arquivo define certos parâmetros de configuração usados pelos agents.
	Ele define todas as propriedades que devem existir, sua documentação e seu valor padrão.
	
	O usuário nunca deve alterar este arquivo que pode sofrer atualizações entre versoes.
	
	As configurações são definidas como itens de uma hashtable.
	O agente irá carregar este arquivo, que deverá retornar uma hashtable com as configurações.
	
	Os valores definidos aqui são os padrões. Se no arquivo de configuração do diretorio \config\agents, o valor não estiver definido, este valor será usado.
	
	
	Caminhos de arquivos
		Items de configuração que representam caminhos de arquivos ou diretorio podem iniciar com "\".
		Quando um item desse tipo iniciar com "\", significa um caminho relativo para o diretorio raiz onde os scripts foram instalados.
		Por exemplo, se a solução foi instalada em "C:\Zabbix\SQLZBX" e o item especifica "\config\keys", então o caminho será expandido para "C:\Zabbix\SQLZBX\config\keys".
		
		A expansão é recursiva, o que significa que se houver items cujo seu valor é uma outra hashtable, e algum ou todos filhos deste items são caminhos de arquivos, a expansão será feitas nos mesmos também.
		
		Também se houver necessidade, items que aceitam array de valores, poderão ser expandidos.
		Não utilize nomes que iniciem com "_", pois estes são reservados e poderão ter seu valor sobrescrito.
		
 #>
 

#Vamos definir alguns valores usados em vários locais.
#Isto são apenas variáveis do powershell com valores que poderao ser usados em mais de um lugar nas configurações abaixo.
#É útil para evitar rescrever valores.
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
			
			
			#Por padrão, substitui a barra por um " ".
			#Se houver o nome mssqlserver depois da barra, retira ele.
			
			$Instance = $VALUES.Instance;
			
			if($Instance -like "*\MSSQLSERVER"){
				return $Instance.replace("\MSSQLSERVER","")
			} else {
				return $Instance.replace("\"," ");
			}
		}
		
	#Este item define grupos de keys.
	#Os grupos de keys são úteis e permitem especificar várias keys baseados em um grupo.
	#Ao executar o agente, o parâmetro KeysGroup pode ser usado para especificar o grupo de keys a ser usado.
	#Isso permite adicionar e remove arquivos facilmente, sem a necessidade de mudar a linha de comando.
	#O usuário pode fornecer quandos grupos quiser.
	#O nome de cada grupo é definido como um item desta hashtable.
	#E o valor deste item é um array, onde cada item do array especifica um caminnho.
	KEYS_GROUP = @{}
		
	#ApplicationName para ser usado nas conexão com as instâncias SQL ao executar os scripts das keys!
	SQL_APP_NAME = $null
	
	#Diretóriio de cache!
	CACHE_DIR = '\cache'
	
	#The storage area!
	#This will define a place where keys defintions that are ps scripts, can use to persist values between executins.
	#The storage areas is a feature of Send-SQL2Zabbix
	#Check README.md in stor at rooot dir for more information.
	STORAGEAREA_DIR = '\stor'
}






















