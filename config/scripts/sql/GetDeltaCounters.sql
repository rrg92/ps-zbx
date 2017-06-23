IF OBJECT_ID('tempdb..#Counters') IS NOT NULL
	DROP TABLE #Counters;

CREATE TABLE #Counters(object_name varchar(2000), counter_name varchar(2000), instance_name varchar(2000));

INSERT INTO #Counters VALUES('%Acess Methods','%Full Scans%','%');
INSERT INTO #Counters VALUES('%Databases','%Log Bytes Flushed%','_Total');
INSERT INTO #Counters VALUES('%Databases','%Log Flush Wait Time%','_Total');
INSERT INTO #Counters VALUES('%Databases','%Log Flush Write Time%','_Total');
INSERT INTO #Counters VALUES('%Databases','%Log Flushes/sec%','_Total');
INSERT INTO #Counters VALUES('%Databases','%Transactions/sec%','_Total');
INSERT INTO #Counters VALUES('%Databases','%Write Transactions/sec%','_Total');
INSERT INTO #Counters VALUES('%General Statistics','%Logins/sec%','_Total');
INSERT INTO #Counters VALUES('%Locks','%Lock Request/sec%','_Total');
INSERT INTO #Counters VALUES('%Locks','%Lock Waits/sec%','_Total');
INSERT INTO #Counters VALUES('%Locks','%Number of Deadlocks/sec%','_Total');
INSERT INTO #Counters VALUES('%SQL Errors','%Errors/sec%','DB Offline Errors');
INSERT INTO #Counters VALUES('%SQL Errors','%Errors/sec%','Kill Connection Errors');
INSERT INTO #Counters VALUES('%SQL STatistics','%Batch Requests/sec%','%');
INSERT INTO #Counters VALUES('%Latches','%Latch Waits/sec%','%');
INSERT INTO #Counters VALUES('%Latches','%Total Latch Wait Time%','%');



SELECT DISTINCT
	CounterName = REPLACE(STUFF(RTRIM(LTRIM(PC.object_name)),1,CHARINDEX(':',PC.object_name),''),' ','')
		+'.'+
	REPLACE(LTRIM(PC.counter_name),' ','')
		+
	ISNULL('.'+NULLIF(REPLACE(LTRIM(PC.instance_name),' ',''),''),'')
	,CounterValue = CONVERT(bigint,PC.cntr_value)
FROM
	sys.dm_os_performance_counters PC
	INNER JOIN
	#Counters C
		ON RTRIM(LTRIM(PC.object_name)) like C.object_name
		AND RTRIM(LTRIM(PC.counter_name)) like C.counter_name
		AND RTRIM(LTRIM(PC.instance_name)) like C.instance_name
WHERE
	PC.cntr_type = 272696576
