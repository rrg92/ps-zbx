param($S,$Q=$null,$i=$null,$D="master",[switch]$MultipleRS = $false, $OutputMessages = $true)

$ErrorActionPreference="stop";
#Save current location
push-location
#Change current location
set-location (Split-Path -Parent $MyInvocation.MyCommand.Definition )

Function New-RSReader {return New-Object PSObject -Prop @{reader=$null;readCount=0;hadNext=$null;error=$null}};
Function Get-RS {param($RSReader) return ReaderResultRest($RSReader) };
Function Close-Connection {param($c) $c.Dispose()}

try{

	. ".\readerResult.ps1"
	

#Creating the connection 
	$ConnectionString = @(
		"Server=$($S)"
		"Database=$($D)"
		"Integrated Security=True"
	)

	if(!$Pooling){
		$ConnectionString += "Pooling=false"
	}
	
	$QueryResults 	= New-Object PSObject -Prop @{ results = @(); messages=@() };
	$Messages		= @(); #Represent the message and errors generated by t-sql..
	
	$queryToRun=$Q;
	if(!$queryToRun){
		$queryToRun = (Get-Content $i) -join "`r`n";
	}
	
	if(!$queryToRun){
		throw "invalid query!"
	}
	
	try {
		$NewConex = New-Object System.Data.SqlClient.SqlConnection
		$NewConex.ConnectionString = $ConnectionString -Join ";" 
		$NewConex.OpenAsync()
		
		#Errors 11 to 16 will be treated as event, in order to allow query process fully (simulating ssms)
		$NewConex.FireInfoMessageEventOnUserErrors = $true;
		
		#Register Info Message event handler...
		$InfoMessageParams = @{Out=$OutputMessages; Events=@()};			
		$InfoMessageSubcriber = Register-ObjectEvent -InputObject $NewConex -EventName "InfoMessage"
		
		#Setup commands...
		$commandTSQL = $NewConex.CreateCommand()
		$commandTSQL.CommandText = $queryToRun;
		$commandTSQL.CommandTimeout = 0;
		
		#Execute and get results...
		$ContinueTheRead = $true;
		try {
			$result = $commandTSQL.ExecuteReaderAsync();
			return;
			#Waiting...
			do {
				write-host "Waiting for results..."
				$WaitResult = [Threading.WaitHandle]::WaitAny(@($IAsyncResult.AsyncWaitHandle),1000)
			} while( $WaitResult -eq [Threading.WaitHandle]::WaitTimeout )
			
			
			
		} catch {
		
			#Check if base exception is SQL Exceptions...
			$Bex = $_.Exception.GetBaseException();
			
			if($Bex -is [System.Data.SqlClient.SqlException]){
				$QueryResults.messages += $Bex.Errors;
			}
			else {
				throw; #Was another error from .NET . Script must ends.
			}
			
		}
		

		#Create the reader object. It will contains the return data from instance...
		$r = New-RSReader
		$r.reader = $result;
		
		if($r.reader){
			$r.HadNext = $true;
			$r.readCount = 0;
		}
		
		write-host "async handle state: " $IAsyncResult.IsCompleted;
		
		while( $r.HadNext ){
			try {
			
			
				$QueryResults.results += Get-RS -RsReader $r;
				write-host "Read count: " $r.readCount;
				write-host "async handle state: " $IAsyncResult.IsCompleted;
				
				
			} catch {
				$Bex = $_.Exception.GetBaseException();
				
				if($Bex -is [System.Data.SqlClient.SqlException]){
					$QueryResults.messages += $Bex.Errors;
				}
				else {
					throw; #Was another error from .NET . Script must ends.
				}
				
			} finally {
			
				#Message events.
				Get-Event | ? {$_.Sender.Equals($NewConex)} | %{
					$EventArguments = $_.SourceEventArgs -as [System.Data.SqlClient.SqlInfoMessageEventArgs];
					$QueryResults.messages += $EventArguments.Errors;
					Remove-Event -EventIdentifier $_.EventIdentifier;
				}
			
			}
			
		} 
		
		#Process the event messages!
		

	} finally {
	
		#Message events.
		Get-Event | ? {$_.Sender.Equals($NewConex)} | %{
			$EventArguments = $_.SourceEventArgs -as [System.Data.SqlClient.SqlInfoMessageEventArgs];
			$QueryResults.messages += $EventArguments.Errors;
			Remove-Event -EventIdentifier $_.EventIdentifier;
		}
	
		if($NewConex -and !$MultipleRS){
			write-host "Disposing connection!"
			#$Newconex.Dispose()
		}
		
		if($InfoMessageSubcriber){
			Unregister-Event $InfoMessageSubcriber.Name;
		}
	
	}
	
} finally {
	pop-location
}

return $QueryResults;