<#
	.SYNOPSIS 
		Copies database to another (or same) instance.
		
	.DESCRIPTION
		
		This cmdlet allow you duplicate databases, by copying to a destination instance.
		
	.PARAMETER MyPara
		
	.EXAMPLE
		Copy-SQLDatabase -SourceServerInstance Instance1 -SourceDatabase Database1 -DestinationServerInstance Instance2 -DestinationDatabase Database1_Copy -BackupFolder \\TEMP\SQLbackups
		
		In this example we simply copy database Database1, at Instance1 to Instance2 with name Database1_Copy.
		The backups will be made on \\TEMP\SQLbackups folder. This folder also will be used to restore...
		The files on database will be distributed on availble volumes on destination instance machine.
		
	.EXAMPLE 
		$results = Invoke-ThreadScript @(1..3) {
			param($bound1,$bound2)
			$a = $PsBoundParameters; 
			write-host ("Total `$PsBoundParameters: "+$PsBoundParameters.count)
			if(!$a){$a = @{}}
			$i = 1;
			write-host ("Total `$args: "+$args.count)
			$args | %{$a.add("Args_$i",$_);$i++}
			write-host ("Total unbounc parameters: "+$a.count)
			write-host "ALL PARAMETERS: "
			$a.GetEnumerator() | %{
				write-host ("Arg: "+$_.Key)
				write-host ("	Value: "+$_.Value)
			}
		} -ArgumentList 1,4 -namedArgumentList @{bound1 = 'b1';bound2='b2'}

	.NOTES
	
		TO DO AND KNOW BUGS:
			
#>