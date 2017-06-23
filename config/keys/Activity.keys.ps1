#Contains keys that determine activity.


@{
	#Instance Keys
	"cc.db.mssql.activity.sqlping" 	= "SELECT 1"
	"cc.db.mssql.activity.uptime" 	= "<DIRSCRIPTS>\sql\InstanceUpTime.sql"
	"cc.db.mssql.activity.sqlping" 	= "SELECT 1"
	"cc.db.mssql.activity.sqlping" 	= "SELECT 1"
	
	
	"cc.db.mssql.responsestats[ResponseStats,?]" = "<DIRSCRIPTS>\sql\ResponseStats.sql"
	
	
	"mssql.instance.memory[?CounterName]" = "<DIRSCRIPTS>\sql\MemoryStats.sql"
	"mssql.instance.plancache[?CounterName,?CounterInstanceName]" = "<DIRSCRIPTS>\sql\PLanCacheStats.sql"
	"mssql.instance.sqlstats[?CounterName]" = "<DIRSCRIPTS>\sql\SQLStatistics.sql"
	"mssql.instance.buffman[?CounterName]" = "<DIRSCRIPTS>\sql\BufferManagerCounter.sql"
	"mssql.instance.tempdb.?" = "<DIRSCRIPTS>\sql\tempdbInfo.sql"
	
	
	#Database keys
	"cc.db.mssql.database.count" = "<DIRSCRIPTS>\sql\DataBaseCount.sql"
	"cc.mssql.database.unavail" = "<DIRSCRIPTS>\sql\DatabaseAvailability.sql"
	"cc.mssql.instance.database.backup.qtdtimedout[?BackupType]" = "<DIRSCRIPTS>\sql\DatabaseLastBackup_Agg.sql"
	
	
	"mssql.database.suspectpagecount" = "<DIRSCRIPTS>\sql\SuspectPageCount.sql"
	#"mssql.database.size[?DatabaseName,?]" = "<DIRSCRIPTS>\sql\DatabaseSize.sql"
	
	#Perf counters
	"mssql.perfcounter[?CounterName,?CounterInstanceName]" = "<DIRSCRIPTS>\sql\PerfCounter.sql"
	
	#Aqui é realizado um teste básico de conexão. Se a conexão for feita com sucesso, retorna 1, senão, retorna 0.
	"mssql.instance[ping]" = "SELECT 1"
}