param($Owner)

return "ALTER AUTHORIZATION ON DATABASE::[$($VALUES.PARAMS.DestinationDatabase)] TO [$Owner]";