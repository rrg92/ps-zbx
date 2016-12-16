# ps-zbx
Fornece uma soluço de integração do SQL Server com o Zabbix.

#Visão Geral
PS-ZBX é uma soluço para integrar o SQL Server com o Zabbix através da execuço de scripts SQL e powershell definidos pelo usuário.
Através de um arquivo de configuração é possível especificar os scripts e as chaves do Zabbix que irão ser populados com o resultados do mesmo.
A solução cuida de executar os scrips nas instãncias desejadas e entregar ao zabbix.
Tudo pode ser configurado através de parâmetros e arquivos de configuraço.


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
#\\SQL2\c$\Zabbix\pszbx
#\\SQL2\c$\Zabbix\pszbx
#

#Para realizar a instalaço nestes caminhos, basta executar o mesmo comando, passando o caminho do arquivo:
C:\Temp\ps-zbx-master\install\install.ps1 C:\temp\SQLServers.txt


```
