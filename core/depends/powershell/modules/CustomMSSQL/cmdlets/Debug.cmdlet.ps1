Function Invoke-LoadSMO {
	return (LoadSMO)
}

Function Test-SMOEXec {
	param($ServerInstance,$query = "SELECT @@SERVERNAME as ServerName",$InputFile=$null)
	
	$ErrorActionPreference = "Stop";
	$Results = @{}
	
	& LoadSMO;
	
	$ConnectionString = @(
		"Server=$($ServerInstance)"
		"Database=master"
		"Integrated Security=True"
		"APP=CustomMSSQL - SMO TEST"
		"Pooling=false"
	)
	
	$NewConex = New-Object System.Data.SqlClient.SqlConnection
	$NewConex.ConnectionString = $ConnectionString -Join ";" 
	
	if($InputFile){
		$Query = (Get-Content $InputFile) -join "`r`n";
	}
	
	$serverConnection  = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($NewConex);
	$server = New-Object Microsoft.SqlServer.Management.Smo.Server($serverConnection);
	
	$Results.add("SERVER_CONNECTION",$serverConnection);
	
	try {
		$r = $serverConnection.ExecuteWithResults($query)
		$Results.add("EXEC_RESULT",$r);
		$o = New-Object PSObject -Prop @{_reader=$r};
		$rp = (Invoke-ReaderParse $o);
		$Results.add("READERPARSE_RESULT",$rp);
	} catch {
		$Results.add("EXCEPTION",$_);
		$Results.add("SQL_ERROR",(FormatSQLErrors $_.Exception));
	}
	
	return $results;
}


Function Invoke-ReaderParse {
	#This is a internal function to get SqlDataReader results and convert into a powershell hashtable array.
	#A behavior in powershell cause it call the enumerator of some parameters that are passed.
	#With SqlDataReader, if this happens, the result returned are lost...
	#Thus, this function is for internal comunication only.
	param($readerObject)
	
		$reader = $readerObject._reader;
		$totalColumns = $i = $reader.FieldCount
		[array]$resultset = @()

		write-verbose "Starting get results from a SqlDataReader..."
		write-verbose "The field count is: $totalColumns"
		write-verbose "Starting rows looping..."
		while($reader.read() -eq $true)
		{
			$columnsValue = @{}
			
			write-verbose "A row is available!"
			
			0..($totalColumns-1) | % {
							write-verbose "Getting the columns for this row!"
			
							write-verbose "Getting current column name..."
							$column = $reader.GetName($_); 
							
							write-verbose "Getting current column value..."
							$value = $reader.getValue($_);

							
							if($reader.isDbNull($_)) {
								write-verbose "Current value is null"
								$value = $null
							}
							
							if(!$column){
								write-verbose "Current column has no name. Assing a default name for this."
								$column = "(No Column Name $_)"
							}
							
							write-verbose "The column name is: $column"
							write-verbose "The value of columns will not be displayed."
							
							write-verbose "Adding the column/value pair to internal array..."
							$columnsValue.add($column,$value)
					}
					
				
			write-verbose "Addin the columns array to resultset internal object"
			$resultset += (New-Object PSObject -Prop $columnsValue)
		}

		write-verbose "Returning data to the caller."
		return $resultset;
}

Function Invoke-DebugLockFile {
	param($file,$accessType,$SleepTime = 1000,$Timeout = 0)

	write-host "Try lock file..."
	
	$handle = LockFile -File $File -AccessType $accessType -SleepTime $SleepTime -Timeout $Timeout;
	return $handle;
	
}

Function Invoke-DebugUnlockFile {
	param($handle)

	write-host "Try unlock file..."
	
	$r = UnLockFile $handle;
	return $r;
}