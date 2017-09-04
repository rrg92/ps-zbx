# ps-zbx
Fornece uma solução de integração do SQL Server com o Zabbix.

# Visão Geral

PS-ZBX é uma solução para integrar o SQL Server com o Zabbix através da execução de scripts SQL e powershell definidos pelo usuário. Ele funciona como uma espécie de agente, executando scripts e enviando os resultados para o zabbix.
Através de um arquivo de configuração é possível especificar os scripts e as chaves do Zabbix que irão ser populados com os resultados do mesmo.
A solução cuida de executar os scrips nas instãncias desejadas e entregar ao zabbix.
Tudo pode ser configurado através de parâmetros e arquivos de configuração.


# Como instalar 
Para instalar, baixe o repositorio em um local de sua escolha.
Para este exemplo, suponha que tenha baixado para C:\temp\ps-zbx-master
Abra o powershell e siga as instruções abaixo.

```powershell

#Para instalar o pszbx, você deve executar o script install.ps1 que se encontra no diretorio install.
#Você deve informar o caminho do diretório de instalaçao!
#Por exemplo, para instalar em C:\Zabbix\pszbx, faça:

C:\Temp\ps-zbx-master\install\install.ps1 C:\Zabbix\pszbx

#O proceso de instalação irá copiar os arquivos necessários (boa parte é um cópia dos arquivos baixados).
#e irá fazer alguns ajustes iniciais.

#Você pode realizar a instalação em vários diretórios de servidores remotos.
#Por exemplo, suponha que você tenha o seguinte arquivo C:\temp\SQLServers.txt
#
#\\SQL1\c$\Zabbix\pszbx
#\\SQL2\d$\Zabbix\pszbx
#\\SQL3\t$\Zabbix\pszbx
#

#Para realizar a instalaço nestes caminhos, basta executar o mesmo comando, passando o caminho do arquivo:
C:\Temp\ps-zbx-master\install\install.ps1 C:\temp\SQLServers.txt

#O exemplo acima é útil se você necessita copiar em diretórios diferentes!
#Se você quer instalar no mesmo caminho, pode usar este formato:
C:\Temp\ps-zbx-master\install\install.ps1 -InstallPath C:\zabbix\pszbx -ServerNames 'SQL1','SQL2','SQL3'

#Este exemplo irá acessar as unidade C:\ via admin share \\SERVER\C$\pszbx.
#Note que se em ambos os casos, o acesso via admin share não estiver funcionando, você vai precisar fazer a instalação manual.

```


# Configuração básica
Após a instalação você deve iniciar a execução do agente!
O agente aceita um arquivo de configuração. PAra detalhes das opções do arquivo consulte o arquivo em \core\agents\.config.ps1. Este arquivo define todas as configurações possíveis. Não edite ele.

Você pode editar o arquivo de configuração \config\agents\default.config.ps1.
Sempre que houver upgrades, este arquivo será mantido.

Você tambm pode definir um arquivo de configuração e colocá-lo em um diretório de rede.
Ao executar o agente, você pode usar o parâmetro -ConfigurationFile e passar o caminho de rede para o arquivo.
Isso permite reaproveitar o mesmo arquivo em várias instâncias diferentes.

O arquivo de execução do agente se encontra em \core\agents\DEFAULT.ps1
Abaixo um exemplo de como inciar o agente

```powershell

C:\Zabbix\pszbx\core\agents\DEFAULT.ps1 -Instance 'SQL1\MyInst' -KeysGroup 'DEFAULT' -ConfigurationFile '\\FS\SQL\pszbx\config.ps1' -HostName 'INSTANCIASQL SQL1 MystInst'



```
Você pode usar jobs na instância monitorada para agendar a execução!

# Keysgroup
Keysgroup definem o conjunto de keys a serem enviadas para o zabbix.
Você pode definir no arquivo de configuração.
Por exemplo, você pode definir um keygroup chamado "DEFAULT" que aponta para o arquivo '\\FS\SQL\pszbx\Default.keys.ps1'

O arquivo Default.keys.ps1 deverá ter as definições de mapeamento entre uma chave no zabbix e o script a ser executado.
Um exemplo do formato do arquivo pode ser encontrado em config\Keys\Default.Keys.ps1



