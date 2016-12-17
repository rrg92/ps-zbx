#Sobre os Caches

O diret�rio "cache" na raiz, � um diret�rio que ser� usado pelo agente para salvar arquivos de redes.
Isso permite que o agente se mantenha funcionando quando o arquivo da rede estiver indispon�vel.

O agente DEFAULT poder� fazer caches dos seguintes arquivos:

	- Arquivos de configura��o passado no par�metro -ConfigurationFile
	- Arquivos definidos nos KEYSGROUP
	- Keys definitions
	- Arquivos de scripts usados nas keys definitions.

Para controle, o agente ir� usar o diret�rio "cache" para efetuar o cache.
O diret�rio de cache � mantido entre upgrades.

# Como o Cache funciona

	Ao iniciar, o agente ir� verificar se algum dos arquivos acima s�o de rede analisando o caminho de cada um.
	Os arquivos que forem de rede, ser�o colocados no diret�rio cache.
	O cache manager poder�, de tempos em tempos (veja abaixo para mais detalhes dessa frequencia), atualizar as c�pias locais.
	Ele ir� fazer isso checando a data de modifica��o do arquivo remoto. Se for maior que a da c�pia local, ele ir� copiar.
	Se houver erros, uma mensagem ser� logada no log do agente e a c�pia local ser� mantida.
	Se a c�pia local, por algum motivo que seja, n�o existir, o agente tamb�m ir� tentar realizar a c�pia a partir do remoto.

	O diret�rio de cache possui uma organiza��o para facilitar a localiza��o destes arquivos.
	Na verdade, dentro do diret�rio "cache", s�o criados outros dois sub-diret�rios, cada um desses sendo um cache diferente:

		- agentcache
			Neste diret�rio encontram se os caches feitos pelo pr�prio agente.
			At� o momento, a �nico arquivo que ser� visto aqui � o informado no par�metro ConfigurationFile, se ele for de rede.

			Um subdiret�rio � criado com o nome da inst�ncia SQL informado no par�metro $Instance mais o nome do keygroup, informado em $KeyGroup.
			Dentro do diret�rio fica o cache propriamente dito.
			Isso permite que o agente que referencia a mesma inst�ncia, por�m keysgroup diferente, possa executar independemente de outros.
			Os arquivos nesse diret�rio s�o atualizados somente quando o agente � inciado.

		- send2zabbix
			Neste diret�rio encontram se os caches feitos pelo cmdlet Send-SQL2Zabbix, que � usado pelo agente para executar os scripts e enviar os dados ao zabbix.
			� um cache completamente separado do outro.
			Aqui s�o feito os caches dos arquivos com as keys defintions e scripts sql e powershell (somente aqueles que s�o de rede).
			

			Um subdiret�rio � criado com o nome da inst�ncia SQL informado no par�metro $Instance mais o nome do keygroup, o que permite cada execu��o da mesma inst�ncia, com diferentes keysgroups, ter seu pr�prio cache.
			Os arquivos nesse diret�rio s�o atualizados na frequencia definida em $Reloadtime.



# Estrutura do Cache

	Os caches, independemente de qual seja, possuem a mesma estrutura porque usam o mesmo servi�o de cache manager.
	Em cada cache h� um arquivo chamado mapping.xml. Este arquivo � o banco de dados do cache e � usado pelo mesmo para guardar diversas informa��es a respeito do mesmo, inclusive os mapeamentos dos arquivos remotos para os arquivos locais.
	Em cada cache haver� um diret�rio cujo nome � extens�o dos arquivos que foram em cache. Isso permite encontrar os arquivos pelo tipo mais facilmente.
	Por exemplo, o diret�rio "sql" ir� conter arquivos cuja a extens�o � ".sql".
	Dentro de cada diret�rio estar�o as c�pias dos arquivos remotos. O nome ser� formado pelo nome original do arquivo + um guid + a extens�o.
	Mantendo a extens�o, permite que o arquivo seja utilizado normalmente pelo script como se fosse o arquivo original.


	Note que os arquivos no cache s�o apenas arquivos comuns e o usu�rio poder� fazer a atualiza��o do mesmo diretamente.
	Fazer isso sem a orienta��o de um profissional que conhece essa solu��o mais experiente, poder� resultar em comportamentos inesperados.


	