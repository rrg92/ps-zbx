Function Invoke-DatabaseShrink {

	[CmdLetBinding(SupportsShouldProcess=$True)]
	param(
		$ServerInstance 	= ""
		,$Login			= $null
		,$Password		= $null
		,[switch]$ShowOnly = $false
		,$LogTo			= $null
		,$LogLevel		= "DETAILED"
		,$FilterWhere	= ""
	)
	
	$ErrorActionPreference = "Stop";
	$IsVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
	
	try {
		
		#The GMV is hashtable containing data pertinent to all module.
		$GMV = GetGMV;
		
		#Parameter validation

			if(!$LogTo){
				$LogTo = "#";
			}
	
		#Lets use Logging facilities provided by CustomMSSQL module...
		$L = (New-LogObject)
		$L.LogTo = $LogTo;
		$L.LogLevel = $LogLevel; 
		$L.ExternalVerboseMode = $IsVerbose; 
		
		
		$L | Invoke-Log "Script Starting!" "PROGRESS";
		
		#This contains all values shared by entire script. 
		$VALUES = @{
			PARAMS = (GetAllCmdLetParams)
			SCRIPTS = @{SQL=@{}}
			SQL_LOGON = @{
						AuthType = "Windows";User=$null;Password=$null
					}
		}
		$VALUES.add("SQLDIR","$($GMV.CMDLETSIDR)\Invoke-DatabaseShrink\sql\");

		#If SQL Login is choosed..
		if($Login){
			$VALUES.SQL_LOGON.AuthType = "SQL";
			$VALUES.SQL_LOGON.User = "$Login";
			$VALUES.SQL_LOGON.Password = "$Password";
		}
		
		#Loading SQL Scripts!
		$L | Invoke-Log "Loading SQL Scripts" -Level "VERBOSE";
		
		gci $VALUES.SQLDIR | %{
			$ScriptType = [System.IO.Path]::GetExtension($_.Name);
			$BaseName = $_.BaseName;
			$FullPath = $_.FullName;
			
			$L | Invoke-Log "	Script Type: $ScriptType | Base Name: $BaseName" -Level "VERBOSE";
			
			
			switch($ScriptType.toUpper()){
			
				".SQL" {
					$ScriptContent = (Get-Content $FullPath) -join "`r`n";
				}
				
				".PS1" {
					$ScriptContent = . $FullPath;
				}
				
			}
			
			
			$VALUES.SCRIPTS.SQL.add($BaseName,$ScriptContent);
		} 
		
		
		$L | Invoke-Log "Getting file list to shrink!";
		
		try {
			$GetFilesQuery = $VALUES.SCRIPTS.SQL.GETFILES_FORSHRINK;
			
			#Replace filter, if there are
			
			if($FilterWhere){
				$Filter = "WHERE ($FilterWhere)"
				$GetFilesQuery = $GetFilesQuery.replace("--<WHERE_FILTER>",$Filter);
			}
			
			$FileList = Invoke-NewQuery -ServerInstance $VALUES.PARAMS.ServerInstance -Query $GetFilesQuery -Logon $VALUES.SQL_LOGON
			$L | Invoke-Log "	Success! File count: $($FileList.count)";
		} catch {
			$L | Invoke-Log "	ERROR:";
			throw;
		}
		
		
		$L | Invoke-Log "Starting Shrink Loop...";
		
		:NextFile foreach($file in $FileList){
			$freeSpace 		= ($file.paginasAlocadas-$file.paginas)/128.00
			$fileType		= $file.typeDesc;
			$DatabaseName	= $file.DatabaseName;
			$FileName		= $file.arquivo;
			$FilePath		= $file.filePath;
			
			$L | Invoke-Log "	Database: $DatabaseName File: $FileName Type: $fileType Size:$($freeSpace)MB FilePath: $FilePath";
			
			switch ($fileType) {
			
				"ROWS" {
					$ShrinkCommand = "DBCC SHRINKFILE([$FileName],1,NOTRUNCATE);DBCC SHRINKFILE([$FileName],1,TRUNCATEONLY);";
				}
				
				"LOG" {
					$ShrinkCommand = "DBCC SHRINKFILE([$FileName],1)";
				}
			
			}
			
			if(!$ShrinkCommand){
				$L | Invoke-Log "	No Shrink command!";
				continue :NextFile;
			}

			
			try {
				if($ShowOnly){	
					$L | Invoke-Log "	Command: $ShrinkCommand" -Level "PROGRESS";
				} else {
					$L | Invoke-Log "	Shrink Command: $ShrinkCommand" -Level "VERBOSE";
					$ShrinkResult = Invoke-NewQuery -ServerInstance $VALUES.PARAMS.ServerInstance -Query $ShrinkCommand -Database $DatabaseName -Logon $VALUES.SQL_LOGON;
				}
			} catch {
				$L | Invoke-Log "	ERROR ON SHRINK:" -Level "PROGRESS";
				$L | Invoke-Log ("	"+(FormatSQLErrors $_.Exception)) -Level "PROGRESS";
			}
			
		}
		

		
		$L | Invoke-Log "Script Finished Sucessfully!";
	} finally {
		if($Log.OutBuffer -and $BufferLog){
			write-host @(($Log.OutBuffer) -join "`r`n")
		}
		
		if($ScriptExitCode -and $ExitWithCode){
			exit $ScriptExitCode;
		}
	}
		
	<#
		.SYNOPSIS 
			Shrinks databases on a server
			
		.DESCRIPTION
			Allows Shrink a SQL Server databases, handling all errors.
			If one database fails, the next is fetched and erros are logged.
			
		.EXAMPLE
			
			
		.NOTES
		
			KNOW ISSUES
				
			WHAT'S NEW

	#>
}	