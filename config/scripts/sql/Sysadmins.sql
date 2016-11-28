-- Determina quais os logins devem ou n�o seer sysadmins!
/*
	Este script � respons�vel por determinar se h� logins inv�lidos como sysadmins!
	� poss�vel especificar quais os logins dever�o ser considerados como os sysadmins v�lidos.

	A tabela #Rules cont�m as regras que ditam como os scripts ser�o avaliados.
	Cada linha da tabela representa uma regra. Uma regra diz quais logins dever�o ser sysadmins.
	Por exemplo, para dizer que o login X deve ser sysadmin na inst�ncia Y, basta relizar o seguinte INSERT:
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES('Y','X');

	As colunas aceitam wildcards do operador LIKE, permitindo que filtros mais elabdorados sejam feito:

		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES('SQLP%','X%'); --> Logins que come�em com X em todas as inst�ncias que cont�m SQL.
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL, 'sa'); --> Usu�rio sa em todas as inst�ncias.

	NULL � o mesmo que '%'. O "\" � usado como escape.
	Voc� pode especificar se o login deve ou n�o ser sysadmin com a coluna MustBe. Por padr�o � 1, indicando que o login inserido deve ser sysadmin na inst�ncia.
	Devido ao fato que v�rias regras referentes ao mesmo login podem existir, ent�o � necess�rio eleger uma baseada nos seguintes crit�rios. Caso um crit�rio empate, o pr�ximo ser� analisado.
	Se o �ltimo crit�rio empatar, ent�o a escolha n�o � garantida e poder� ser feita randomicamente pelo SQL Server. Os crit�rios s�o:

		1) A coluna Manual Priority seja maior! Voc� pode especificar uma prioridade manual para for�ar uma regra espec�fica ser escolhida.
		2) A inst�ncia seja informada, isto �, n�o NULL! Note que devido a isso, NULL e '%' t�m diferentes prioridades.
			Se duas regras diferentes s�o eleg�veis, uma contendo InstanceName NULL e outra contendo InstanceName '%', ent�o a regra cujo InstanceName '%' � usada.
		3) Principal seja informado, isto �, n�o NULL! Note que devido a isso, NULL e '%' t�m diferentes prioridades.
			Se duas regras diferentes s�o eleg�veis, uma contendo PrincipalName NULL e outra contendo PrincipalName '%', ent�o a regra cujo PrincipalName '%' � usada.
		4) Nega��o preferencial
			Se duas regras diferentes s�o eleg�veis, um contendo MustBe = 0 e outra MustBe = 1, ent�o a que cont�m MustBe = 0 ser� escolhida!

	Colunas:
		InstanceName	- A inst�ncia
		PrincipalName	- O login que dever� ser sysamin.
		MustBe			- Indica se o login deve (1) ou n�o (0) ser sysadmin.
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
	
	-- Globais! Devem ser sysadmin em qualquer servidor! Incluem contas de sistema e de administra��o por parte da equipeSQL.
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'sa') 
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT AUTHORITY\\SYSTEM');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\SQLSERVERAGENT');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\MSSQL$%');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\MSSQLSERVER');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\SQLAgent%');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'BUILTIN\\Administrators');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\SQLWriter');
		INSERT INTO #Rules (InstanceName,PrincipalName) VALUES(NULL,'NT SERVICE\\Winmgmt');


	-- Espe�ficos de cada inst�ncia!




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
		-- Intruse is amount of logins that are sysadmin, but should not be. (Quantidade de logins que s�o, mas n�o devem ser)
		-- Banned  is the amount of logins that should  be sysadmin, but are (Quantidade de logins que n�o s�o, mas devem seR)
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

