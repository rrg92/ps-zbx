Function Format-SQLErrors {
	param($Exception = $null)

	if(!$Exception){
		$Exception = $error[0].Exception;
	}
	
	return FormatSQLErrors $Exception
}