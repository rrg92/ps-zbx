-- Determina quais os logins devem ou não seer sysadmins!
/*
	Este script é responsável por determinar se há logins inválidos como sysadmins!
	É possível especificar quais os logins deverão ser considerados como os sysadmins válidos.

	A tabela #Rules contém as regras que ditam como os scripts serão avaliados.
	Cada linha da tabela representa uma regra. Uma regra diz quais logins deverão ser sysadmins.
	Por exemplo, para dizer que o login X deve ser sysadmin na instância Y, basta relizar o seguinte INSERT:
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES('Y','X');

	As colunas aceitam wildcards do operador LIKE, permitindo que filtros mais elabdorados sejam feito:

		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES('SQLP%','X%'); --> Logins que começem com X em todas as instâncias que contém SQL.
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL, 'sa'); --> Usuário sa em todas as instâncias.

	NULL é o mesmo que '%'. O "\" é usado como escape.
	Você pode especificar se o login deve ou não ser sysadmin com a coluna MustBe. Por padrão é 1, indicando que o login inserido deve ser sysadmin na instância.
	Devido ao fato que várias regras referentes ao mesmo login podem existir, então é necessário eleger uma baseada nos seguintes critérios. Caso um critério empate, o próximo será analisado.
	Se o último critério empatar, então a escolha não é garantida e poderá ser feita randomicamente pelo SQL Server. Os critérios são:

		1) A coluna Manual Priority seja maior! Você pode especificar uma prioridade manual para forçar uma regra específica ser escolhida.
		2) A instância seja informada, isto é, não NULL! Note que devido a isso, NULL e '%' têm diferentes prioridades.
			Se duas regras diferentes são elegíveis, uma contendo InstanceName NULL e outra contendo InstanceName '%', então a regra cujo InstanceName '%' é usada.
		3) Principal seja informado, isto é, não NULL! Note que devido a isso, NULL e '%' têm diferentes prioridades.
			Se duas regras diferentes são elegíveis, uma contendo PrincipalName NULL e outra contendo PrincipalName '%', então a regra cujo PrincipalName '%' é usada.
		4) Negação preferencial
			Se duas regras diferentes são elegíveis, um contendo MustBe = 0 e outra MustBe = 1, então a que contém MustBe = 0 será escolhida!

	Colunas:
		InstanceName	- A instância
		PrincipalName	- O login que deverá ser sysamin.
		MustBe			- Indica se o login deve (1) ou não (0) ser sysadmin.
*/

USE [master];

IF OBJECT_ID('tempdb..#Rules') IS NOT NULL
	DROP TABLE #Rules;

CREATE TABLE #Rules(
	ID bigint NOT NULL IDENTITY PRIMARY KEY
	,InstanceName nvarchar(2000)
	,PrincipalName nvarchar(2000)
	,MustBe bit DEFAULT 1
	,ManualPriority int DEFAULT 0
);

--> REGRAS...
	
	-- Globais! Devem ser sysadmin em qualquer servidor! Incluem contas de sistema e de administração por parte da equipeSQL.
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'sa') 
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT AUTHORITY\\SYSTEM');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\SQLSERVERAGENT');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\MSSQL$%');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\MSSQLSERVER');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\SQLAgent%');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'BUILTIN\\Administrators');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\SQLWriter');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\Winmgmt');


	-- Espeíficos de cada instância!




-------------------------------------- CORE DO SCRIPT --------------------------------------
 
IF OBJECT_ID('tempdb..#EffectiveRules') IS NOT NULL
	DROP TABLE #EffectiveRules;
	
IF OBJECT_ID('tempdb..#Membership') IS NOT NULL
	DROP TABLE #Membership;

SELECT  
	 CurrentInstance	= @@SERVERNAME
	,PrincipalName		= SP.name
	,MustBe				= ISNULL(R.MustBe,0)
	,RuleID				= R.ID
	,RulePriority		= ROW_NUMBER() OVER(
								PARTITION BY
									SP.name
								ORDER BY
									 R.ManualPriority DESC
									,CASE WHEN R.InstanceName IS NOT NULL THEN 1 ELSE 2 END 
									,CASE WHEN R.PrincipalName IS NOT NULL THEN 1 ELSE 2 END
									,ISNULL(R.MustBe,0)
							)
INTO
	#EffectiveRules
FROM 
	sys.server_principals SP
	LEFT JOIN
	#Rules R
		ON	@@SERVERNAME LIKE  ISNULL(R.InstanceName,'%') ESCAPE '\'  COLLATE Latin1_General_CI_AI
		AND SP.name LIKE  ISNULL(R.PrincipalName,'%') ESCAPE '\'  COLLATE Latin1_General_CI_AI


SELECT 
	* 
	,IsSysAdmin = ISNULL(SA.IsInRole,0)
INTO
	#Membership
FROM 
	#EffectiveRules ER
	OUTER APPLY
	(
		SELECT  
			1 as IsInRole
		FROM 
			sys.server_role_members RM 
		WHERE 
			RM.role_principal_id = SUSER_ID('sysadmin')
			AND
			RM.member_principal_id = SUSER_ID(ER.PrincipalName)
	) SA
WHERE
	ER.RulePriority = 1


IF PROGRAM_NAME() LIKE '%SQL2ZABBIX%'
BEGIN

	-- Concepts:
		-- Intruse is amount of logins that are sysadmin, but should not be. (Quantidade de logins que são, mas não devem ser)
		-- Banned  is the amount of logins that should  be sysadmin, but are (Quantidade de logins que não são, mas devem seR)
	SELECT
		 [count]		= COUNT(CASE WHEN MustBe = 1 OR IsSysAdmin = 1 THEN 1 END)											
		,intruses		= COUNT(CASE WHEN MustBe = 0 AND IsSysAdmin = 1 THEN 1 END)
		,excluded		= COUNT(CASE WHEN MustBe = 1 AND IsSysAdmin = 0 THEN 1 END) 
	FROM
		#Membership


	RETURN;
END


SELECT
	*
	,IsIntruse	= CASE WHEN MustBe = 0 AND IsSysAdmin = 1 THEN 1 END
	,IsExcluded	= CASE WHEN MustBe = 1 AND IsSysAdmin = 0 THEN 1 END
FROM
	#Membership
WHERE
	MustBe = 1 OR IsSysAdmin = 1
ORDER BY
	IsSysAdmin DESC
	,MustBe DESC

