param($VALUES)

$SourceDatabase = $VALUES.PARAMS.SourceDatabase

$TSQL = "ALTER DATABASE [$SourceDatabase] SET READ_ONLY WITH ROLLBACK IMMEDIATE;"

return $TSQL;