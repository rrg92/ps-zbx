Function NewDataReaderParser {
	$o = New-Object PsObject -Prop @{
		#This will contain the _reader object...
		reader = $null
		
		#This store the number of times that read of object was request. This is number of calls to NextResult...
		ReadCount = 0
		
		#This indicates if previous call to NextResult returned $true. When this value is $false, then no more result is available to return and client can stop to requesting rows...
		hadNext = $true #It must be initialize as $true, in order to make a at lear one attempt.
	}

	#this will be GetNextResultSet method of object...
	$GetNextResultSet = [scriptblock]::create({
		#Lets initialize some useful variables...
		[int]$ColumnCount 	= $this.reader.FieldCount;
		[bool]$GotColumns = $false;
		[array]$resultset = @();
		[Object]$TemplateObject = New-Object PsObject;
		[string[]]$ColumnNames	= @();
		[int]$reads = 0;
		
		try {
			#Now, lets configure hadNext to points to null. This indicates that we dont know about if there are most results to fetch...
			$this.hadNext = $null;
			
			#If we already read sometime, then we must call NextResult in order to get another results.
			#Note that this call will block if query still running, and can throw sql exceptions...
			if($this.readCount -ge 1){
				$this.hadNext = $this.reader.NextResult();
			} else {
				#If it just first time, then just set to hadNext...
				$this.hadNext = $true;
			}
			
		} finally {
			$this.readCount++; #Increment our readcount, indepently if throws exceptions or not...
		}
		
		
		
		#Lets start read the rows from current resultset...
		$t = New-Object System.Diagnostics.StopWatch;
		$t2 = New-Object System.Diagnostics.StopWatch;
		
		
		$t.start();
		while($this.reader.read() -eq $true)
		{
			$reads++;
			#Lets build a sample object that will contains the columns...
			if(!$GotColumns){
				$GotColumns = $true;
				
				$i = $ColumnCount;
				#For each column...
				while($i--){
					$ColumnName 	= $this.reader.GetName($i);  
					
					#If hasn't name, then generate a default...
					if(!$ColumnName){
						$ColumnName = "(No Column Name $_)"
					}
					
					$TemplateObject | Add-Member -Name $ColumnName -Type Noteproperty -Value $null;
					$ColumnNames += $ColumnName;
				}

			}

			#Alright, at this point, we can iterate over column for get the value, for each row...
			
			#For each column value, in current row...
			
			$i = $ColumnCount;
			
			
			$t2.restart();
			while($i--){
				$ColumnName = $ColumnNames[$i]; #Get current colummn name from column name cache...;
				
				if($this.reader.isDbNull($i)){
					$ColumnValue = $null;
				} else {
					$ColumnValue = $this.reader.getValue($i);
				}
				
				$TemplateObject.$ColumnName = $ColumnValue;
			}
			$t2.stop();
			updatePerf "COLUMN_VALUE_LOOP" $t2
			if($reads -eq 1)  {updatePerf "COLUMN_VALUE_LOOP_FIRST" $t2}
			
			
			$resultset += $TemplateObject.psobject.copy();
		}
		
		$t.stop();
		updatePerf "READ_ROW_LOOP" $t	

		
		#Returning to caller...
		return $resultset;
	
	})

	
	$o | Add-Member -Type ScriptMethod -Name GetNextResultSet -Value $GetNextResultSet;
	
	return $o;
}

Function NewDataReaderParser2 {

	
	$o = New-Object PsObject -Prop @{
		#This will contain the _reader object...
		reader = $null
		
		#This store the number of times that read of object was request. This is number of calls to NextResult...
		ReadCount = 0
		
		#This indicates if previous call to NextResult returned $true. When this value is $false, then no more result is available to return and client can stop to requesting rows...
		hadNext = $true #It must be initialize as $true, in order to make a at lear one attempt.
	}

	#this will be GetNextResultSet method of object...
	$GetNextResultSet = [scriptblock]::create({
			$RsReader = $this;
			$reader = $RsReader.reader
			$totalColumns = $i = $reader.FieldCount
			[array]$resultset = @()
			
			try {
				$RsReader.hadNext = $null; #hadNext indicates if previous operation result  had something. It must explcityr returns null or false. Doubts operations must cause a new result attempt.
				
				if($RSReader.readCount -ge 1){
					write-verbose "Getting next result!"
					
					try {
						$RsReader.hadNext = $reader.NextResult()
					} catch {
						$RsReader.hadNext = $true; #We assume that if error was throwed, then somehting there was...
						throw;
					}
					
				} else {
					$RsReader.hadNext = $true;
				}
			
			} finally {
				$RSReader.readCount++;
			}


			write-verbose "Starting get results from a SqlDataReader..."
			write-verbose "The field count is: $totalColumns"
			write-verbose "Starting columns looping..."
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
	
	})

	
	$o | Add-Member -Type ScriptMethod -Name GetNextResultSet -Value $GetNextResultSet;
	
	return $o;
}


Function NewDataReaderParser2-1 {
	$o = New-Object PsObject -Prop @{
		#This will contain the _reader object...
		reader = $null
		
		#This store the number of times that read of object was request. This is number of calls to NextResult...
		ReadCount = 0
		
		#This indicates if previous call to NextResult returned $true. When this value is $false, then no more result is available to return and client can stop to requesting rows...
		hadNext = $true #It must be initialize as $true, in order to make a at lear one attempt.
	}

	#this will be GetNextResultSet method of object...
	$GetNextResultSet = [scriptblock]::create({
		#Lets initialize some useful variables...
		$ColumnCount 	= $this.reader.FieldCount;
		$GotColumns = $false;
		[array]$resultset = @();
		$TemplateObject = New-Object PsObject;
		$NewTemplate	= { return $TemplateObject.psobject.copy(); }
		$ColumnNames	= @();
		
		try {
			#Now, lets configure hadNext to points to null. This indicates that we dont know about if there are most results to fetch...
			$this.hadNext = $null;
			
			#If we already read sometime, then we must call NextResult in order to get another results.
			#Note that this call will block if query still running, and can throw sql exceptions...
			if($this.readCount -ge 1){
				$this.hadNext = $this.reader.NextResult();
			} else {
				#If it just first time, then just set to hadNext...
				$this.hadNext = $true;
			}
			
		} finally {
			$this.readCount++; #Increment our readcount, indepently if throws exceptions or not...
		}
		
		
		
		#Lets start read the rows from current resultset...
		while($this.reader.read() -eq $true)
		{
			#Lets build a sample object that will contains the columns...
			if(!$GotColumns){
				$GotColumns = $true;
				
				#For each column...
				0..($ColumnCount-1) | % {
					$ColumnName 	= $this.reader.GetName($_);  
					
					#If hasn't name, then generate a default...
					if(!$ColumnName){
						$ColumnName = "(No Column Name $_)"
					}
					
					$TemplateObject | Add-Member -Name $ColumnName -Type Noteproperty -Value $null;
					$ColumnNames += $ColumnName;
				}

			}

			#Alright, at this point, we can iterate over column for get the value, for each row...
			
			#For each column value, in current row...
			
			0..($ColumnCount-1) | % {
				
				$ColumnName = $ColumnNames[$_]; #Get current colummn name from column name cache...
				
				
				if($this.reader.isDbNull($_)){
					$ColumnValue = $null;
				} else {
					$ColumnValue = $this.reader.getValue($_);
				}
				
				
				$TemplateObject.$ColumnName = $ColumnValue;
				
			}
			
			
			
			$resultset += $TemplateObject.psobject.copy();
		}
		
		#Returning to caller...
		return $resultset;
	
	})

	
	$o | Add-Member -Type ScriptMethod -Name GetNextResultSet -Value $GetNextResultSet;
	
	return $o;
}
