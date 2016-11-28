IF OBJECT_ID('cmsprops.cpInstanceProperties') IS NULL
	EXEC('CREATE VIEW cmsprops.cpInstanceProperties AS SELECT 1 AS StubVersion');
GO

ALTER VIEW
	[cmsprops].[cpInstanceProperties]
AS
	-- Esta parte da query irá gerar uma linha para cada membro da hierarquia de um server. Isso nos vai permitir obter todas as descrições da qual
	-- um server herda tags!
	WITH ServersParents AS
	(

		SELECT
			S.server_id
			,S.server_group_id  parentGroup
			,CONVERT(bigint,1) as Priori
		FROM
			msdb..sysmanagement_shared_registered_servers S

		UNION ALL

		SELECT
			SP.server_id
			,SG.parent_id
			,CONVERT(bigint,SP.Priori+1) as Priori
		FROM
			ServersParents SP
			INNER JOIN
			msdb..sysmanagement_shared_server_groups SG
				ON SG.server_group_id = SP.parentGroup
		WHERE
			SG.parent_id IS NOT NULL
	)
	SELECT
		 F.server_id
		,F.propName
		,F.propValue
	FROM
	(
		SELECT
			 SP.server_id
			,SP.propName
			,SP.propValue
			,ROW_NUMBER() OVER(PARTITION BY SP.server_id,SP.PropName ORDER BY SP.Priori) as Priority
		FROM
			(
				SELECT
					S.server_id
					,S.Priori
					,CP.propName
					,CP.propValue
				FROM
				(
					SELECT
						S.server_id
						,S.description
						,0 as Priori
					FROM
						msdb..sysmanagement_shared_registered_servers S

					UNION ALL
				
					SELECT
						SP.server_id
						,SG.description
						,SP.Priori
					FROM
						msdb..sysmanagement_shared_server_groups SG
						INNER JOIN
						ServersParents SP
							ON SP.parentGroup = SG.server_group_id
				) S
				CROSS APPLY
				(
					SELECT
						 PFP.PropName
						,RTRIM(LTRIM(SUBSTRING(S.description,PFP.PropPos+1,PFP.ExprEnd-PFP.PropPos-1))) as propValue
					FROM
						(
							SELECT
									PIP.propName
								,CHARINDEX(':',S.description,PIP.ExprtStart) as PropPos
								,CHARINDEX(']',S.description,PIP.ExprtStart) as ExprEnd
							FROM
								(
									SELECT
										*
										,NULLIF(PATINDEX(CONVERT(varchar(100),'%[[]'+propName+':%'),S.description),0) as ExprtStart
									FROM
										cmsprops.CMSProperties P		
								) PIP -- Properties and Initital Positions
							WHERE
								PIP.ExprtStart IS NOT NULL
						) PFP  -- Properties and Final Positions
				) CP -- Calculated Properties


				UNION ALL

				--> This select finds properties of current CMS SERVER. It queries extended properties of master databases.
					-- The equivalent extended properties must be registered on ExtendedMapping table, to engine correctly associate a CMSProperty with a extended property;
				SELECT
					 -1		
					,0 -- Take priority over all others, because is was defined on server!		
					,X.propName
					,X.propValue
				FROM
					(
						SELECT 
							p.propName
							,CONVERT(sysname,X.value) AS propValue
							,ROW_NUMBER() OVER(PARTITION BY P.propName ORDER BY P.propName) AS DuplicatePropertyPriority
						FROM
							master.sys.fn_listextendedproperty(NULL, NULL, null, null, null, null, default) X
							JOIN
							cmsprops.ExtendedMapping M
								ON M.ExtendedProperty = X.name
							JOIN
							cmsprops.CMSProperties P
								ON P.propName = m.CMSProp
					) X
				WHERE
					X.DuplicatePropertyPriority  = 1

			) SP --Server properties!
	) F
	WHERE
		F.Priority = 1
GO


EXEC sp_refreshsqlmodule 'cmsprops.cpInstanceProperties';
GO