# Este � um arquivo com m�tricas comuns a serem monitoradas em todas as inst�ncias.
#	Esta m�tricas apenas relatam o estado do ambiente. N�o precisam ser enviadas em um tempo curto demais.
#	O tempo ideal seria a cada 1 minuto.

@{
	#Instance Keys
	"mssql.instance[?]" = "<DIRSCRIPTS>\sql\InstanceUpTime.sql"
	"mssql.instance.memory[?CounterName]" = "<DIRSCRIPTS>\sql\MemoryStats.sql"
	"mssql.instance.plancache[?CounterName,?CounterInstanceName]" = "<DIRSCRIPTS>\sql\PLanCacheStats.sql"
	"mssql.instance.sqlstats[?CounterName]" = "<DIRSCRIPTS>\sql\SQLStatistics.sql"
	"mssql.instance.buffman[?CounterName]" = "<DIRSCRIPTS>\sql\BufferManagerCounter.sql"
	"mssql.instance.tempdb.?" = "<DIRSCRIPTS>\sql\tempdbInfo.sql"
	#"mssql.instance.security.sysadmins.?" = "<DIRSCRIPTS>\sql\Sysadmins.sql"
	"mssql.instance[ResponseStats,?]" = "<DIRSCRIPTS>\sql\ResponseStats.sql"
	
	#Database keys
	"mssql.database.count" = "<DIRSCRIPTS>\sql\DataBaseCount.sql"
	"mssql.database.unavail" = "<DIRSCRIPTS>\sql\DatabaseAvailability.sql"
	"mssql.instance.database.backup.qtdtimedout[?BackupType]" = "<DIRSCRIPTS>\sql\DatabaseLastBackup_Agg.sql"
	"mssql.database.suspectpagecount" = "<DIRSCRIPTS>\sql\SuspectPageCount.sql"
	#"mssql.database.size[?DatabaseName,?]" = "<DIRSCRIPTS>\sql\DatabaseSize.sql"
	
	#Perf counters
	"mssql.perfcounter[?CounterName,?CounterInstanceName]" = "<DIRSCRIPTS>\sql\PerfCounter.sql"
	
	#Aqui � realizado um teste b�sico de conex�o. Se a conex�o for feita com sucesso, retorna 1, sen�o, retorna 0.
	"mssql.instance[ping]" = "SELECT 1"
}