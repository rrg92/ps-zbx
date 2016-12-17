#Sobre os Caches

O diretório "cache" na raiz, é um diretório que será usado pelo agente para salvar arquivos de redes.
Isso permite que o agente se mantenha funcionando quando o arquivo da rede estiver indisponível.

O agente DEFAULT poderá fazer caches dos seguintes arquivos:

	- Arquivos de configuração passado no parâmetro -ConfigurationFile
	- Arquivos definidos nos KEYSGROUP
	- Keys definitions
	- Arquivos de scripts usados nas keys definitions.

Para controle, o agente irá usar o diretório "cache" para efetuar o cache.
O diretório de cache é mantido entre upgrades.

# Como o Cache funciona

Ao iniciar, o agente irá verificar se algum dos arquivos acima são de rede analisando o caminho de cada um.
Os arquivos que forem de rede, serão colocados no diretório cache.
O cache manager poderá, de tempos em tempos (veja abaixo para mais detalhes dessa frequencia), atualizar as cópias locais.
Ele irá fazer isso checando a data de modificação do arquivo remoto. Se for maior que a da cópia local, ele irá copiar.
Se houver erros, uma mensagem será logada no log do agente e a cópia local será mantida.
Se a cópia local, por algum motivo que seja, não existir, o agente também irá tentar realizar a cópia a partir do remoto.

O diretório de cache possui uma organização para facilitar a localização destes arquivos.
Na verdade, dentro do diretório "cache", são criados outros dois sub-diretórios, cada um desses sendo um cache diferente:

	- agentcache
		Neste diretório encontram se os caches feitos pelo próprio agente.
		Até o momento, a único arquivo que será visto aqui é o informado no parâmetro ConfigurationFile, se ele for de rede.

		Um subdiretório é criado com o nome da instância SQL informado no parâmetro $Instance mais o nome do keygroup, informado em $KeyGroup.
		Dentro do diretório fica o cache propriamente dito.
		Isso permite que o agente que referencia a mesma instância, porém keysgroup diferente, possa executar independemente de outros.
		Os arquivos nesse diretório são atualizados somente quando o agente é inciado.

	- send2zabbix
		Neste diretório encontram se os caches feitos pelo cmdlet Send-SQL2Zabbix, que é usado pelo agente para executar os scripts e enviar os dados ao zabbix.
		É um cache completamente separado do outro.
		Aqui são feito os caches dos arquivos com as keys defintions e scripts sql e powershell (somente aqueles que são de rede).
		

		Um subdiretório é criado com o nome da instância SQL informado no parâmetro $Instance mais o nome do keygroup, o que permite cada execução da mesma instância, com diferentes keysgroups, ter seu próprio cache.
		Os arquivos nesse diretório são atualizados na frequencia definida em $Reloadtime.



# Estrutura do Cache

Os caches, independemente de qual seja, possuem a mesma estrutura porque usam o mesmo serviço de cache manager.
Em cada cache há um arquivo chamado mapping.xml. Este arquivo é o banco de dados do cache e é usado pelo mesmo para guardar diversas informações a respeito do mesmo, inclusive os mapeamentos dos arquivos remotos para os arquivos locais.
Em cada cache haverá um diretório cujo nome á extensão dos arquivos que foram em cache. Isso permite encontrar os arquivos pelo tipo mais facilmente.
Por exemplo, o diretório "sql" irá conter arquivos cuja a extensão é ".sql".
Dentro de cada diretório estarão as cópias dos arquivos remotos. O nome será formado pelo nome original do arquivo + um guid + a extensão.
Mantendo a extensão, permite que o arquivo seja utilizado normalmente pelo script como se fosse o arquivo original.


Note que os arquivos no cache são apenas arquivos comuns e o usuário poderá fazer a atualização do mesmo diretamente.
Fazer isso sem a orientação de um profissional que conhece essa solução mais experiente, poderá resultar em comportamentos inesperados.


	