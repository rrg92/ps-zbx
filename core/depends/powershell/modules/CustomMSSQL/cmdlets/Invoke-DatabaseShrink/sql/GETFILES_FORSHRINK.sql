USE master;

IF OBJECT_ID('tempdb..#EspacoUsado') IS NOT NULL
	DROP TABLE #EspacoUsado;

CREATE TABLE
	#EspacoUsado
	(
		 database_id int
		,arquivo sysname
		,paginas bigint
		,paginasAlocadas bigint
		,maxPages bigint
		,typeDesc varchar(50)
		,filePath nvarchar(2000)
		,DatabaseName AS DB_NAME(database_id)
	)
;

EXEC sp_MSforeachdb N'
	USE [?];

	INSERT INTO
		#EspacoUsado
		(
			database_id
			,arquivo
			,paginas
			,paginasAlocadas
			,maxPages
			,typeDesc
			,filePath
		)
	SELECT
		DB_ID()
		,name
		,FILEPROPERTY(name,''SpaceUsed'')
		,size
		,max_size
		,type_desc
		,physical_name
	FROM
		sys.database_files;
'

ALTER TABLE #EspacoUsado ADD ID bigint;

;WITH IDCalculado AS
(
	SELECT
		ID
		,ROW_NUMBER() OVER(  
				ORDER BY
					CASE
						WHEN EU.typeDesc = 'LOG' THEN 1
						ELSE 2
					END
					,EU.paginasAlocadas-EU.paginas ASC
			) NovoID
	FROM
		#EspacoUsado EU
)
UPDATE IDCalculado SET ID = NovoID


SELECT
	*
FROM
	#EspacoUsado EU
--<WHERE_FILTER>	/*This part will be replaced by a custom filter, if users pass some*/
ORDER BY
	EU.ID