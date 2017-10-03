param($VALUES)

$LoginName = $VALUES.LIMITED_USER.NAME;

$Command = "
	SET XACT_ABORT ON;
	BEGIN TRAN;
		IF SUSER_ID('$LoginName') IS NOT NULL
		BEGIN
				EXEC('USE master; DROP LOGIN [$LoginName]');
		END
		
		IF USER_ID('$LoginName') IS NOT NULL
		BEGIN
			EXEC('DROP USER [$LoginName]');
		END
	COMMIT;
"

& $VALUES.SCRIPT_STORE.FUNCTIONS.Log " DropLimitedUserCommand: $Command"

return $Command;