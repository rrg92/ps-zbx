param($VALUES)


if(!$VALUES.LIMITED_USER.NAME){
	 $VALUES.LIMITED_USER.NAME = "CopySQLDatabaseLimited_"+$VALUES.PARAMS.DestinationDatabase;
}

$TmpGuid = [Guid]::NewGuid().Guid;

if(!$VALUES.LIMITED_USER.PASSWORD){
	 $VALUES.LIMITED_USER.PASSWORD = $TmpGuid;
}

$LoginName = $VALUES.LIMITED_USER.NAME;
$Password = $VALUES.LIMITED_USER.PASSWORD;
$LimitedUserPolicy = $VALUES.PARAMS.LimitedUserPolicy;


$Command = "
	SET XACT_ABORT ON;
	BEGIN TRAN;
		DECLARE @Policy varchar(100);
		SET @Policy = '$LimitedUserPolicy';

		IF SUSER_ID('$LoginName') IS NOT NULL
		BEGIN
			IF @Policy = 'MustCreate'
			BEGIN
				RAISERROR('LIMITEDUSER_LOGIN_EXISTS: $LoginName',16,1);
				RETURN;
			END 
			ELSE IF @Policy = 'DropIfExist'
				EXEC('DROP LOGIN [$LoginName]');
		END
			
		EXEC('USE master; CREATE LOGIN [$LoginName] WITH PASSWORD = ''$Password''')

		IF USER_ID('$LoginName') IS NOT NULL
		BEGIN
			IF @Policy = 'MustCreate'
			BEGIN
				RAISERROR('LIMITEDUSER_USER_EXISTS: $LoginName',16,1);
				RETURN;
			END 
			ELSE IF @Policy = 'DropIfExist'
				EXEC('DROP USER [$LoginName]');

		END

		EXEC('CREATE USER [$LoginName] FROM LOGIN [$LoginName]');
		
		EXEC sp_addrolemember 'db_owner','$LoginName';
		
	COMMIT;
"

& $VALUES.SCRIPT_STORE.FUNCTIONS.Log " LimitedPolicy is: $LimitedUserPolicy" "DETAILED"
& $VALUES.SCRIPT_STORE.FUNCTIONS.Log " CreateLimitedUserCommand: $Command"

return $Command;