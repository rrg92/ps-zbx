-- Determina se as bases estão disponíveis ou não!
/*
	Este script é responsável por determinar se há bases indisponível.
	O script verifica a coluna "StateDesc" para determinar a disponibilidade da base, mas futuras implementações podem usar outras informações.

	A tabela #DatabaseRules contém as regras que ditam como o script irá avaliar o valor de StateDesc.
	Cada linha da tabela representa uma regra.
	Uma regra diz quais estados são considerados como disponibilidade.
	Por exemplo, para dizer que o estado ONLINE é considerado como disponibilidade para a base X do servidor Y, faça o seguinte INSERT:
		INSERT INTO #DatabaseRules (InstanceName,DatabaseName,StateDesc) VALUES('Y','X','ONLINE');

	As colunas aceitam wildcards do operador LIKE, permitindo que filtros mais elabdorados sejam feito:

		INSERT INTO #DatabaseRules (InstanceName,DatabaseName,StateDesc) VALUES('SQLP%',NULL,'ONLINE'); --> Considerar o estado ONLINE em todas as bases de instâncias que possuem no nome SQLP
		INSERT INTO #DatabaseRules (InstanceName,DatabaseName,StateDesc) VALUES(NULL,NULL,'R%'); --> Considerar todos os estados que começem com R.

	NULL é o mesmo que '%'. O "\" é usado como escape.

	Colunas:
		InstanceName - A instância
		DatabaseName - A base
		StateDesc - O estado.
*/

USE [master];

IF OBJECT_ID('tempdb..#DatabaseRules') IS NOT NULL
	DROP TABLE #DatabaseRules;

CREATE TABLE #DatabaseRules(
	ID bigint NOT NULL IDENTITY PRIMARY KEY
	,InstanceName nvarchar(2000)
	,DatabaseName nvarchar(2000)
	,StateDesc varchar(100)
);

--> REGRAS...

	INSERT INTO #DatabaseRules (InstanceName,DatabaseName,StateDesc) VALUES(NULL,NULL,'ONLINE') --> Todas as bases, o ONLINE é considerado!!


	--> Bases que foram restauradas no mínimo uma vez nos últimos 30 dias!
		INSERT INTO #DatabaseRules (InstanceName,DatabaseName,StateDesc)
		SELECT
			 NULL
			,D.databaseName COLLATE Latin1_General_CI_AI
			,S.StateDesc  COLLATE Latin1_General_CI_AI
		FROM
			(
				SELECT DISTINCT 
					destination_database_name COLLATE Latin1_General_CI_AI
				FROM 
					msdb..restorehistory 
				WHERE 
					restore_type = 'D' 
					AND 
					restore_date >= DATEADD(DD,-30,CURRENT_TIMESTAMP)
				GROUP BY
					destination_database_name
				HAVING
					COUNT(*) >= 1
			) D(databaseName)
			CROSS JOIN
			(
				SELECT CONVERT(varchar(100),'RESTORING')
				UNION ALL
				SELECT CONVERT(varchar(100),'RECOVERING')
			) S(stateDesc)

-------------------------------------- CORE DO SCRIPT --------------------------------------
IF OBJECT_ID('tempdb..#EffectiveRules') IS NOT NULL
	DROP TABLE #EffectiveRules;
	
IF OBJECT_ID('tempdb..#DatabaseAvail') IS NOT NULL
	DROP TABLE #DatabaseAvail;

SELECT  
	 @@SERVERNAME as CurrentInstance
	,D.name	AS DatabaseName
	,D.state_desc
	,R.ID as RuleID
INTO
	#EffectiveRules
FROM 
	sys.databases D 
	LEFT JOIN
	#DatabaseRules R
		ON	D.name LIKE  ISNULL(R.DatabaseName,'%') ESCAPE '\' COLLATE Latin1_General_CI_AI
		AND @@SERVERNAME LIKE  ISNULL(R.InstanceName,'%') ESCAPE '\'  COLLATE Latin1_General_CI_AI
		AND D.state_desc LIKE  ISNULL(R.StateDesc,'%') ESCAPE '\'  COLLATE Latin1_General_CI_AI

SELECT
	DatabaseName
	,C.state_desc
	,MAX(CASE WHEN C.RuleId IS NULL THEN 0 ELSE 1 END) as IsAvail
INTO
	#DatabaseAvail
FROM
	#EffectiveRules C
GROUP BY
	DatabaseName
	,C.state_desc

IF PROGRAM_NAME() LIKE '%SQL2ZABBIX%'
BEGIN

	SELECT
		COUNT(*) as UnavailableCount
	FROM
		#DatabaseAvail DA
	WHERE
		DA.IsAvail = 0

	RETURN;
END

SELECT
	*
FROM
	#DatabaseAvail DA
ORDER BY
	DA.IsAvail
	,DA.DatabaseName


