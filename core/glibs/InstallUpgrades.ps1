#Cont�m fun��es referentes ao processo de instala��o e upgrade da solu��o!


#Atualiza de uma versao para outra!
Function Upgrade {
	param($DestBaseDir, $SourceBaseDir)
	
	$ErrorActionPReference="Stop";
	
	
	write-host "Upgrading $DestBaseDir from $SourceBaseDir"
	#Obt�m todos os sub-diretorios no diret�rio base
	$Dirs = gci $DestBaseDir | ? {$_.PsIscontainer}
	
	
	#Gera um novo de um diret�rio de backup.
	#O diretoriio de backup fica no diretorio upgrade.
	$Backupdir = GetUpgradeBackupDir $DestBaseDir;
	
	
	write-host "BackupDir: $Backupdir"
	#Faz o backup da estrutura existente para recupera��o em caso de erros!
	try {
		#Copia os diret�rios, exceto o diretorio de upgrade e de cache! pois ele pode contar muitos outros arquivos!!
		$Dirs | ?{ @('upgrade') -NotContains $_.Name; } | copy -force -recurse -Destination $Backupdir;
	} catch {
		throw "CANNOT_BACKUP_EXISTENT_DIR: BackupDir: $BackupDir Error: $_";
	}
	write-debug 'Backups feito. O proximo passo sera a remocao!'
	
	#Remove toda a estrutura existente, que ser� substitu�da pela nova!
	write-host "Removendo diret�rios existentes!"
	$Removed = @(); #Esta vari�vel ir� conter os diret�rio que j� foram removidos!
	#Para sub-diretorio...
	$StartRollback = $false;
	try {
		$Dirs | %{
			$CurrentDir = $_;
			write-host "Current dir is: $($CurrentDir.FullName)"
			
			#Se for o diret�rio config, ignora, pois estes podem conter dados do usu�rio...
			if( @('config','log','upgrade') -Contains $CurrentDir.Name){
				return;
			}
			
			#Tenta deletar o diretorio!
			try {
				write-host "Tentando remover: $($Currentdir.FullName)"
				$CurrentDir  | Remove-Item -force -recurse;
				$Removed += $CurrentDir; #se foi removido com sucesso, adiciona ao array de removidos...
				write-host "	Diretorio $($currentDir.Name) removido!"
			} catch {
				$OriginalError = $_;
				$StartRollback = $true;
				throw "REMOVE_OLD_DIRECTORY_ERROR: $_";
			}

		}
	} catch {
		if($StartRollback){
				write-host "Erro ao remover o diret�rio $($CurrentDir.Name). Iniciando ROLLBACK. Cause: $OriginalError";
				UpgradeRollbackRemove -BackupDir $BackupDir -DestDir $DestBaseDir -Removed $Removed -CurrentDir $CurrentDir
				throw "UPGRADE_FAILED: $OriginalError"
				return;
		} else {
			throw
		}
	}

	
	write-host "Copiando novos items!"
	$SourceDirs = gci $SourceBaseDir | ? {$_.PsIscontainer -and @('upgrade','log','config') -NotContains $_.Name}
	$StartRollback = $false;
	try {
		
		$Copiados = @();
		try {
			$SourceDirs | %{
				$CurrentDir = $_;
				write-host "copiando $($_.Name)..."
				$Copiados += copy $_.FullName $DestBaseDir -recurse -force -PassThru -EA "Stop";
			}
		} catch {
			$OriginalError = $_;
			$StartRollback = $true;
			throw 'COPY_NEW_DIRECTORY_ERROR: $_';
		}
		
	} catch {
		if($StartRollback){
			write-host "Erro ao copiar o diret�rio $($CurrentDir.Name). Iniciando ROLLBACK. Cause: $OriginalError";
			UpgradeRollbackCopy -Copiados $Copiados
			UpgradeRollbackRemove -BackupDir $BackupDir -DestDir $DestBaseDir -Removed $Removed -CurrentDir $null
			throw "UPGRADE_FAILED: $OriginalError"
		} else {
			throw
		}
	}

	write-host "Sucess!"
}

#Faz o rollback da remo��o dos arquivos...
Function UpgradeRollbackRemove {
	param($BackupDir, $DestDir, $Removed, $CurrentDir)
	
		$BackupDir = AddDirSlash $BackupDir;	
		$DestDir = AddDirSlash $DestDir;

		write-host 'Backup Directory: ' $BackupDir 'Destination Directory: ' $DestDir;
		
		try {
		
		#Se existem diret�rios que j� foram removidos, copia os mesmos inteiros de volta...
			if($Removed){
				write-host "Restabelecendo diret�rios j� removidos!"
				
				#Item n�o pode ser removido, fazendo rollback do que j� foi removido!
				$Removed | %{
					write-host "Restaurando backup de $($_.FullName) para $($DestDir)"
					$BackupPath = $BackupDir  + $_.Name;
					copy $BackupPath $DestDir -force -recurse;
				}
			}
			
			if($CurrentDir){
				
				#Determina o caminho para o �ltimo diret�rio, no diret�rio de backup.
				write-host "Restaurando itens do �ltimo diret�rio onde ocorreu a falha..."
				$BackupPath = $BackupDir + $CurrentDir.Name;
				
				write-host "Backup path: $BackupPath"
				#Para cada arquivo que existe no diretorio de backup...
				gci ($BackupPath+'\*') -recurse | %{
					$Backup_ArquivoAtual 	= $_; #Cont�m uma refer�ncia para o item que representa o arquivo atual...
					#Indica se o item � um diret�rio...
					$IsDir				= $Backup_ArquivoAtual.PsIscontainer;
					
					#Obt�m o caminho relativo para o arquivo, a partir da raiz da solu��o no backup...
					$Backup_PathRelative	= GetRelativePath -FullPath $Backup_ArquivoAtual.FullName -BaseDir $BackupDir 
					
					#Monta o caminho para o arquivo original...
					$OriginalPath		= $DestDir + $Backup_PathRelative;
					
					
					#Se for um diret�rio...
					if( $IsDir ){
						#Se o diretorio n�o existir, copia do backup...
						if(![System.IO.Directory]::Exists($OriginalPath)){
							write-host "Item n�o existe, copiando de $($Backup_ArquivoAtual.FullName) para $OriginalPath"
							copy $Backup_ArquivoAtual.FullName $OriginalPath -force -recurse
						} 
					} else {
						#Se o arquivo n�o existir, copia do backup...
						if(![System.IO.File]::Exists($OriginalPath)){
							write-host "Item n�o existe, copiando de $($Backup_ArquivoAtual.FullName) para $OriginalPath"
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
		
		write-host "ROLLBACK REALIZADO COM SUCESSO!"
		return;
}

#Faz o rollback da c�pia de novos arquivos!
Function UpgradeRollbackCopy {
	param($Copiados)
	
	try {
		write-host "Items copaidos que serao deletados: $($Copiados.count)"
		$Copiados | ?{ if($_.PsIsContainer){[IO.Directory]::Exists($_.FullName)}else{[IO.File]::Exists($_.FullName)} } | Remove-Item -force -recurse;
	} catch {
		throw "FATAL_ERROR_CANNOT_ROLLBACK: $_"
	}
	
}

#Instala a solu��o
Function InstallSolution {
	param($DestinationBase, $SourceBaseDir)
	
	$ErrorActionPreference = "Stop";
	
	write-host "Creating new em $_";
	
	#Se o diretorio de install n�o existe, cria-o.
	if(![System.IO.Directory]::Exists($DestinationBase)){
		mkdir $DestinationBase | out-Null
	} else{
		write-host "Diret�rio j� existe... Limpando..."
		gci ($DestinationBase+'\*') -recurse | Remove-Item -force -recurse;
	}

	
	$Dirs = gci $SourceBaseDir | ? {$_.PsIscontainer -and @('upgrade') -NotContains $_.Name }
	
	$Copiados = @()
	$Dirs  | %{
		try {
			write-host "Copiando  $($_.Name)"
			$Copiados += copy $_.FullName $DestinationBase -recurse -force -passthru
		} catch {
			$OriginalError = $_;
			try {
				write-host "Erro na instala��o: $_. O procesos de rollback sera realizado!"
				gci $DestinationBase -recurse | Remove-Item -force -recurse;
			} catch {
				throw "FATAL_ERROR_CANNOT_ROLLBACK: $_"
			}
			
			throw "INSTALL_FAILED: $OriginalError"
		}

	}
	
	#Limpa o diretorio de log...
	gci ($DestinationBase+'\log\*') -recurse | ? {!$_.PsIsContainer} | Remove-Item -force;
}


Function GetInstallMSSQLScript {
	param($ScriptName)

	$InstallDir = GetInstallDir
	$ScriptFile	= $InstallDir + '\mssql' +'\'+ $ScriptName;
	
	return $ScriptFile;
}


Function CreateSQLJobs {
	param($SQLInstance, $BaseDir, $Creds)

	$SQLAuth = @{
		AuthType="Windows";
		Login="";
		Password="";
	}
	
	if($Creds){
		$SQLAuth.Login = $Creds.GetNetworkCredentials().UserName
		$SQLAuth.Password = $Creds.GetNetworkCredentials().Password
	}
	
	
	$SQLJobDefault = GetInstallMSSQLScript 'jobs\JOBZabbixDefault.sql';
	$Vars = @{
		JobName 	= 'DBA: MON DEFAULT' 
		BaseDir		= $BaseDir
		AgentName	= 'DEFAULT.ps1'
		KeysGroup	= 'DEFAULT'
	}
	$SQLScript = ReplaceSQLPsZbxVar -SQLScript $SQLJobDefault -Vars $Vars;
	
	try {
		write-host 'Criando jobs default...';
		Invoke-NewQuery -ServerInstance $SQLInstance -Logon $SQLAuth -Query $SQLScript -Database 'msdb'
	} catch {
		write-host 'Falha ao criar o job $($Vars.JobName): $_. Crie manualmente depois!'
	}
}

