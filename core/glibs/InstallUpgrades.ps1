#Contém funções referentes ao processo de instalação e upgrade da solução!


#Atualiza de uma versao para outra!
Function Upgrade {
	param($DestBaseDir, $SourceBaseDir)
	
	$ErrorActionPReference="Stop";
	
	$Log = GetPsZbxVar 'INSTALL_LOG_OBJECT';
	
	if(!$Log){
		throw 'INVALID_LOG_OBJECT!'
	}
	
	
	$Log | Invoke-Log "Upgrading $DestBaseDir from $SourceBaseDir" "DETAILED"
	#Obtém todos os sub-diretorios no diretório base
	$Dirs = gci $DestBaseDir | ? {$_.PsIscontainer}
	
	
	#Gera um novo de um diretório de backup.
	#O diretoriio de backup fica no diretorio upgrade.
	$Backupdir = GetUpgradeBackupDir $DestBaseDir;
	
	
	$Log | Invoke-Log "BackupDir: $Backupdir" "DETAILED"
	#Faz o backup da estrutura existente para recuperação em caso de erros!
	try {
		#Copia os diretórios, exceto o diretorio de upgrade e de cache! pois ele pode contar muitos outros arquivos!!
		$Dirs | ?{ @('upgrade') -NotContains $_.Name; } | copy -force -recurse -Destination $Backupdir;
	} catch {
		throw "CANNOT_BACKUP_EXISTENT_DIR: BackupDir: $BackupDir Error: $_";
	}
	$Log | Invoke-Log 'Backups feito. O proximo passo sera a remocao!' 'DEBUG';
	#Esse comando será mantido até que o XLogging suporte write-debug... nos levels do tipo DEBUG...
	write-debug 'Backups feito. O proximo passo sera a remocao!'
	
	#Remove toda a estrutura existente, que será substituída pela nova!
	$Log | Invoke-Log "Removendo diretórios existentes!" "DETAILED"
	$Removed = @(); #Esta variável irá conter os diretório que já foram removidos!
	#Para sub-diretorio...
	$StartRollback = $false;
	try {
		$Dirs | %{
			$CurrentDir = $_;
			$Log | Invoke-Log "Current dir is: $($CurrentDir.FullName)" "DETAILED"
			
			#Se for algum dos diretórios abaixo, não os remove pois pode conter dados do usuário
			if( @('config','log','upgrade','cache') -Contains $CurrentDir.Name){
				return;
			}
			
			#Tenta deletar o diretorio!
			try {
				$Log | Invoke-Log "Tentando remover: $($Currentdir.FullName)" "DETAILED"
				$CurrentDir  | Remove-Item -force -recurse;
				$Removed += $CurrentDir; #se foi removido com sucesso, adiciona ao array de removidos...
				$Log | Invoke-Log "	Diretorio $($currentDir.Name) removido!" "DETAILED"
			} catch {
				$OriginalError = $_;
				$StartRollback = $true;
				throw "REMOVE_OLD_DIRECTORY_ERROR: $_";
			}

		}
	} catch {
		if($StartRollback){
				$Log | Invoke-Log "Erro ao remover o diretório $($CurrentDir.Name). Iniciando ROLLBACK. Cause: $OriginalError" "DETAILED";
				UpgradeRollbackRemove -BackupDir $BackupDir -DestDir $DestBaseDir -Removed $Removed -CurrentDir $CurrentDir
				throw "UPGRADE_FAILED: $OriginalError"
				return;
		} else {
			throw
		}
	}

	
	$Log | Invoke-Log "Copiando novos items!" "DETAILED"
	$SourceDirs = gci $SourceBaseDir | ? {$_.PsIscontainer -and @('upgrade','log','config') -NotContains $_.Name}
	$StartRollback = $false;
	try {
		
		$Copiados = @();
		try {
			$SourceDirs | %{
				$CurrentDir = $_;
				$Log | Invoke-Log "copiando $($_.Name)..." "DETAILED"
				$Copiados += copy $_.FullName $DestBaseDir -recurse -force -PassThru -EA "Stop";
			}
		} catch {
			$OriginalError = $_;
			$StartRollback = $true;
			throw 'COPY_NEW_DIRECTORY_ERROR: $_';
		}
		
	} catch {
		if($StartRollback){
			$Log | Invoke-Log "Erro ao copiar o diretório $($CurrentDir.Name). Iniciando ROLLBACK. Cause: $OriginalError" "DETAILED";
			UpgradeRollbackCopy -Copiados $Copiados
			UpgradeRollbackRemove -BackupDir $BackupDir -DestDir $DestBaseDir -Removed $Removed -CurrentDir $null
			throw "UPGRADE_FAILED: $OriginalError"
		} else {
			throw
		}
	}

	CleanLogDirectory ($DestBaseDir+'\log') -UpgradeClean; 
	$Log | Invoke-Log "Sucess!" "DETAILED"
}

#Faz o rollback da remoção dos arquivos...
Function UpgradeRollbackRemove {
	param($BackupDir, $DestDir, $Removed, $CurrentDir)
		
		$Log = GetPsZbxVar 'INSTALL_LOG_OBJECT';
	
		if(!$Log){
			throw 'INVALID_LOG_OBJECT!'
		}
	
		$BackupDir = AddDirSlash $BackupDir;	
		$DestDir = AddDirSlash $DestDir;

		$Log | Invoke-Log "Backup Directory:  $BackupDir Destination Directory:  $DestDir" "DETAILED";
		
		try {
		
		#Se existem diretórios que já foram removidos, copia os mesmos inteiros de volta...
			if($Removed){
				$Log | Invoke-Log "Restabelecendo diretórios já removidos!" "DETAILED"
				
				#Item não pode ser removido, fazendo rollback do que já foi removido!
				$Removed | %{
					$Log | Invoke-Log "Restaurando backup de $($_.FullName) para $($DestDir)" "DETAILED"
					$BackupPath = $BackupDir  + $_.Name;
					copy $BackupPath $DestDir -force -recurse;
				}
			}
			
			if($CurrentDir){
				
				#Determina o caminho para o último diretório, no diretório de backup.
				$Log | Invoke-Log "Restaurando itens do último diretório onde ocorreu a falha..." "DETAILED"
				$BackupPath = $BackupDir + $CurrentDir.Name;
				
				$Log | Invoke-Log "Backup path: $BackupPath" "DETAILED"
				#Para cada arquivo que existe no diretorio de backup...
				gci ($BackupPath+'\*') -recurse | %{
					$Backup_ArquivoAtual 	= $_; #Contém uma referência para o item que representa o arquivo atual...
					#Indica se o item é um diretório...
					$IsDir				= $Backup_ArquivoAtual.PsIscontainer;
					
					#Obtém o caminho relativo para o arquivo, a partir da raiz da solução no backup...
					$Backup_PathRelative	= GetRelativePath -FullPath $Backup_ArquivoAtual.FullName -BaseDir $BackupDir 
					
					#Monta o caminho para o arquivo original...
					$OriginalPath		= $DestDir + $Backup_PathRelative;
					
					
					#Se for um diretório...
					if( $IsDir ){
						#Se o diretorio não existir, copia do backup...
						if(![System.IO.Directory]::Exists($OriginalPath)){
							$Log | Invoke-Log "Item não existe, copiando de $($Backup_ArquivoAtual.FullName) para $OriginalPath" "DETAILED"
							copy $Backup_ArquivoAtual.FullName $OriginalPath -force -recurse
						} 
					} else {
						#Se o arquivo não existir, copia do backup...
						if(![System.IO.File]::Exists($OriginalPath)){
							$Log | Invoke-Log "Item não existe, copiando de $($Backup_ArquivoAtual.FullName) para $OriginalPath" "DETAILED"
							#usa o New-Item pra criar o arquivo primeiro antes de copiar o conteudo e evitar o erro...
							New-Item -force $OriginalPath -Type File | Out-null;
							copy $Backup_ArquivoAtual.FullName  $OriginalPath -force -recurse
						} 
					}
					
				}
			}

		} catch {
			throw "FATAL_ERROR_CANNOT_ROLLBACK: $_"
		}
		
		$Log | Invoke-Log "ROLLBACK REALIZADO COM SUCESSO!" "DETAILED"
		return;
}

#Faz o rollback da cópia de novos arquivos!
Function UpgradeRollbackCopy {
	param($Copiados)
	
	$Log = GetPsZbxVar 'INSTALL_LOG_OBJECT';

	if(!$Log){
		throw 'INVALID_LOG_OBJECT!'
	}
	
	try {
		$Log | Invoke-Log "Items copaidos que serao deletados: $($Copiados.count)" "DETAILED"
		$Copiados | ?{ if($_.PsIsContainer){[IO.Directory]::Exists($_.FullName)}else{[IO.File]::Exists($_.FullName)} } | Remove-Item -force -recurse;
	} catch {
		throw "FATAL_ERROR_CANNOT_ROLLBACK: $_"
	}
	
}

#Instala a solução
Function InstallSolution {
	param($DestinationBase, $SourceBaseDir)
	
	$ErrorActionPreference = "Stop";
	
	$Log = GetPsZbxVar 'INSTALL_LOG_OBJECT';

	if(!$Log){
		throw 'INVALID_LOG_OBJECT!'
	}
	
	$Log | Invoke-Log "Creating new em $_" "DETAILED";
	
	#Se o diretorio de install não existe, cria-o.
	if(![System.IO.Directory]::Exists($DestinationBase)){
		mkdir $DestinationBase | out-Null
	} else{
		$Log | Invoke-Log "Diretório já existe... Limpando..." "DETAILED"
		gci ($DestinationBase+'\*') -recurse | Remove-Item -force -recurse;
	}

	
	$Dirs = gci $SourceBaseDir | ? {$_.PsIscontainer -and @('upgrade') -NotContains $_.Name }
	
	$Copiados = @()
	$Dirs  | %{
		try {
			$Log | Invoke-Log "Copiando  $($_.Name)" "DETAILED"
			$Copiados += copy $_.FullName $DestinationBase -recurse -force -passthru
		} catch {
			$OriginalError = $_;
			try {
				$Log | Invoke-Log "Erro na instalação: $_. O procesos de rollback sera realizado!" "DETAILED"
				gci $DestinationBase -recurse | Remove-Item -force -recurse;
			} catch {
				throw "FATAL_ERROR_CANNOT_ROLLBACK: $_"
			}
			
			throw "INSTALL_FAILED: $OriginalError"
		}

	}
	
	#Limpa o diretorio de log...
	CleanLogDirectory ($DestinationBase+'\log')
}


#Limpa o diretório de log
Function CleanLogDirectory {
	param($LogDir, [switch]$UpgradeClean)
	
	$Log = GetPsZbxVar 'INSTALL_LOG_OBJECT';

	if(!$Log){
		throw 'INVALID_LOG_OBJECT!'
	}
	
	if(!$UpgradeClean){
		$Log | Invoke-Log "Cleaning entire log directory!" "DETAILED";
		gci $LogDir -recurse | Remove-Item -recurse -force;
		return;
	}
	
	$Log | Invoke-Log "Cleaning log directories..." "DETAILED"
	
	#sub-diretório para limpar!
	@('install') | %{
		$FullPath = $LogDir + '\' + $_
		
		if(![IO.Directory]::Exists($FullPath)){
			return;
		}
		
		$Log | Invoke-Log "	Cleaning: $FullPath" "DETAILED";
		try {
			gci $FullPath -recurse | remove-item -recurse -force;
		} catch {
			$Log | Invoke-Log "	Error: $_" "DETAILED";
		}
	}
	
}

Function GetInstallMSSQLScript {
	param($ScriptName)

	$InstallDir = GetInstallDir
	$ScriptFile	= $InstallDir + '\mssql' +'\'+ $ScriptName;
	
	return $ScriptFile;
}


#Cria e obtém um novo diretório de log para o processo de instalação!
Function GetInstallLogDir {
	$Logdir = GetDefaultLogDir;
	return (GetLogFileName -AsDir -Dir "$LogDir\install" )
	
}


#Check  upgrade dir size, in order to clean...
Function UpgradeDirReport {
	param($DestBaseDir, $RemoveBase)

	$UpgradeDir = $DestBaseDir + '\upgrade';
	
	
	#Obtém  a lista de diretorios!
	$TopLevels = gci $UpgradeDir | ? {$_.PsIsContainer};
	
	#Adiciona a data!
	$TopLevels | sort Name -desc | %{
		$Name = $_.Name;
		$UpgradeTime = [Datetime]::ParseExact($Name,"yyyyMMdd_HHmmss",[Globalization.CultureInfo]::InvariantCulture)
		$_ | Add-Member -Type Noteproperty -Name UpgradeTime -Value $UpgradeTime;
		$_ | Add-Member -Type Noteproperty -Name Size -Value $null;
		
		write-host "Collecting size on $Name --> $($UpgradeTime)... " -NoNewLine
		$Size = (gci $_.FullName -recurse | ? {!$_.PsIsContainer} | Measure-Object -Property Length -Sum).sum;
		$_.Size = $Size;
		write-host "  ($Size bytes)"
	}
	
	#Quantidade:
	[decimal]$TotalSize = ($TopLevels | Measure-Object -Property Size -Sum).sum;
	
	$Units  = "b","K","M","G","T";
	$u = 0;
	
	$LastSize  = $TotalSize;
	while( $LastSize/1024.00 -ge 1 ){
		$LastSize /= 1024.00;
		$u++;
		
		if($u -eq $Units.length){
			$LastSize *= 1024.00;
			$u = $Units.Length-1;
			break;
		}
	}
	
	write-host "Existem $($TopLevels.count). Size: $LastSize $($Units[$u])";
	
	do {
		$Confirmation = $null;
		$RemoveBase = Read-Host "Digite a partir de qual vc quer remover"
		
		if($RemoveBase){
			$Dir = $TopLevels | ? {$_.Name -eq $RemoveBase};
			
			if(!$Dir){
				write-host "Nome $RemoveBase não encontrado! Tente novamente!";
				$Confirmation = "n";
				continue;
			}
		
			$DateToRemove = $Dir.UpgradeTime;
		} else {
			break;
		}

		$Confirmation = Read-Host "Confirma a data [y/n]? $($DateToRemove)"
	} while( $Confirmation -and $Confirmation -ne 'y' )
	
	if(!$Confirmation){
		write-host "Cancelado!";
		return;
	}
	
	$ForRemove = $TopLevels | ? {$_.UpgradeTime -le $DateToRemove};
	write-host "Removendo $($ForRemove.count) items..."
	$ForRemove | Remove-Item -recurse -force;
}