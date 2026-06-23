CREATE OR ALTER PROCEDURE ans.ZSP_update_mapping_jdv(@Profile VARCHAR(250), @Version VARCHAR(250), @Data VARCHAR(MAX))
AS BEGIN 	
	DECLARE @XML XML = CONVERT(XML, @Data);
	DECLARE @ProfilVersionID BIGINT;

	SELECT @ProfilVersionID = PV.id 
			FROM ans.ans_profil AS P
			INNER JOIN ans.ans_profil_version AS PV ON PV.profil_ref = P.id
			WHERE P.name = @Profile AND PV.name = @Version;

	-- ans.ans_jeu_de_valeur
	WITH 
		XMLNAMESPACES(DEFAULT 'urn:ihe:iti:svs:2008'),
		CTE AS (
		SELECT
			N.x.value('(./@name)[1]', 'VARCHAR(250)') AS name,
			N.x.value('(./@displayName)[1]', 'VARCHAR(250)') AS display_name,
			N.x.value('(./@id)[1]', 'VARCHAR(250)') AS id
			FROM @Xml.nodes('/RetrieveValueSetResponse/ValueSet') AS N(x)
		)
	INSERT INTO ans.ans_jeu_de_valeur(name, code_system)
	SELECT COALESCE(J.name, J.display_name), J.id 
		FROM CTE AS J
		WHERE NOT EXISTS(SELECT * FROM ans.ans_jeu_de_valeur AS Z WHERE Z.code_system = J.id);

	-- ans.ans_terminologie
	WITH 
		XMLNAMESPACES(DEFAULT 'urn:ihe:iti:svs:2008'),
		CTE AS (
		SELECT
			N.x.value('(./@codeSystem)[1]', 'VARCHAR(250)') AS code_system
			FROM @Xml.nodes('/RetrieveValueSetResponse/ValueSet/ConceptList/Concept') AS N(x)
		)
	INSERT INTO ans.ans_terminologie(code_system)
	SELECT DISTINCT J.code_system
		FROM CTE AS J
		WHERE NOT EXISTS(SELECT * FROM ans.ans_terminologie AS Z WHERE Z.code_system = J.code_system);

	-- ans.ans_terminologie_valeur
	WITH 
		XMLNAMESPACES(DEFAULT 'urn:ihe:iti:svs:2008'),
		CTE AS (
		SELECT
			N.x.value('(./@codeSystem)[1]', 'VARCHAR(250)') AS code_system,
			N.x.value('(./@code)[1]', 'VARCHAR(250)') AS code,
			N.x.value('(./@displayName)[1]', 'VARCHAR(250)') AS display_name
			FROM @Xml.nodes('/RetrieveValueSetResponse/ValueSet/ConceptList/Concept') AS N(x)
		)
	INSERT INTO ans.ans_terminologie_valeur(terminologie_ref, code, display_name)
	SELECT DISTINCT 
		T.id,
		J.code,
		J.display_name
		FROM CTE AS J
		INNER JOIN ans.ans_terminologie AS T ON T.code_system = J.code_system
		WHERE NOT EXISTS(SELECT * FROM ans.ans_terminologie_valeur AS Z WHERE Z.terminologie_ref = T.id AND Z.code = J.code);
	
	-- ans.ans_jeu_de_valeur_valeur
	WITH 
		XMLNAMESPACES(DEFAULT 'urn:ihe:iti:svs:2008'),
		CTEValue AS (
		SELECT
			N.x.value('(./@codeSystem)[1]', 'VARCHAR(250)') AS code_system,
			N.x.value('(./@code)[1]', 'VARCHAR(250)') AS code,
			N.x.value('(./@displayName)[1]', 'VARCHAR(250)') AS display_name
			FROM @Xml.nodes('/RetrieveValueSetResponse/ValueSet/ConceptList/Concept') AS N(x)
		),
		CTEInfo AS (
		SELECT
			N.x.value('(./@name)[1]', 'VARCHAR(250)') AS name,
			N.x.value('(./@displayName)[1]', 'VARCHAR(250)') AS display_name,
			N.x.value('(./@id)[1]', 'VARCHAR(250)') AS id
			FROM @Xml.nodes('/RetrieveValueSetResponse/ValueSet') AS N(x)
		)
	INSERT INTO ans.ans_jeu_de_valeur_valeur(jeu_de_valeur_ref, terminologie_valeur_ref, profil_version_ref)
	SELECT DISTINCT 
		AJ.id,
		TV.id,		
		@ProfilVersionID
		FROM CTEValue AS J
		INNER JOIN ans.ans_terminologie AS T ON T.code_system = J.code_system
		INNER JOIN ans.ans_terminologie_valeur AS TV ON TV.terminologie_ref = T.id AND TV.code = J.code,
		CTEInfo AS I
		INNER JOIN ans.ans_jeu_de_valeur AS AJ ON AJ.code_system = I.id		
		WHERE 
			NOT EXISTS(SELECT * 
						FROM ans.ans_jeu_de_valeur_valeur AS Z 
						WHERE Z.jeu_de_valeur_ref = AJ.id AND
							  Z.terminologie_valeur_ref = TV.id AND
							  Z.profil_version_ref = @ProfilVersionID)
END

GO

CREATE OR ALTER PROCEDURE ans.ZSP_update_mapping_mapping(@Profil VARCHAR(250), @Version VARCHAR(250), @JSON VARCHAR(MAX))
AS BEGIN 
	DECLARE @TableMapping TABLE(kprocess_value VARCHAR(50), for_import BIT, ans_jeu_de_valeur_valeur_ref BIGINT, code VARCHAR(250), code_system VARCHAR(250));
	DECLARE @ProfilVersionID BIGINT;
	DECLARE @KProcessJeuValeurID BIGINT;

	SELECT @ProfilVersionID = PV.id 
		FROM ans.ans_profil_version AS PV
		INNER JOIN ans.ans_profil AS P ON PV.profil_ref = P.id
		WHERE P.name = @Profil AND PV.name = @Version;

	-- Création des jeux de valeur si nécessaire
	WITH 
		CTE AS (
		SELECT
			J.name AS name,
			J.table_name AS table_name
			FROM OPENJSON(@JSON) WITH
			(
				name VARCHAR(250) '$.name',
				table_name VARCHAR(250) '$.tableName'
			) AS J
		)
	INSERT INTO ans.kprocess_jeu_de_valeur(name, table_name)
	SELECT J.name, J.table_name
		FROM CTE AS J
		WHERE NOT EXISTS(SELECT * FROM ans.kprocess_jeu_de_valeur AS Z WHERE Z.name = J.name);

	SELECT @KProcessJeuValeurID = id 
		FROM ans.kprocess_jeu_de_valeur AS KJV
		INNER JOIN OPENJSON(@JSON) WITH
		(
			name VARCHAR(250) '$.name'
		) AS J ON J.name = KJV.name

	INSERT INTO @TableMapping(kprocess_value, code, code_system, for_import)
	SELECT 
		M.kprocess,
		M.code,
		M.code_system,
		1
	FROM OPENJSON(@JSON) WITH
			(
				name VARCHAR(250) '$.name',
				table_name VARCHAR(250) '$.tableName',
				jeu_de_valeur_ans VARCHAR(250) '$.jeuDeValeurs',
				mapping NVARCHAR(MAX) '$.mapping' AS JSON 
			) AS J
			CROSS APPLY OPENJSON(J.mapping) WITH
			(
				kprocess VARCHAR(250) '$.kprocess',
				code VARCHAR(250) '$.code',
				code_system VARCHAR(250) '$.codeSystem',
				ignore BIT '$.ignore'
			) AS M;

	INSERT INTO @TableMapping(kprocess_value, code, code_system, for_import)
	SELECT 
		M.kprocess,
		V.code,
		V.code_system,
		0
	FROM OPENJSON(@JSON) WITH
			(
				name VARCHAR(250) '$.name',
				table_name VARCHAR(250) '$.tableName',
				jeu_de_valeur_ans VARCHAR(250) '$.jeuDeValeurs',
				mapping NVARCHAR(MAX) '$.mapping' AS JSON 
			) AS J
			CROSS APPLY OPENJSON(J.mapping) WITH
			(
				kprocess VARCHAR(250) '$.kprocess',
				code VARCHAR(250) '$.code',
				code_system VARCHAR(250) '$.codeSystem',
				ignore BIT '$.ignore',
				additional_values NVARCHAR(MAX) '$.additionalValues' AS JSON
			) AS M
			CROSS APPLY OPENJSON(M.additional_values) WITH
			(
				code VARCHAR(250) '$.code',
				code_system VARCHAR(250) '$.codeSystem'
			) AS V;


	
					  
	-- Résolution de ans_jeu_de_valeur_valeur_ref
	UPDATE TM 
		SET ans_jeu_de_valeur_valeur_ref = (SELECT 
				JV.id 
				FROM ans.ans_terminologie_valeur AS TV
				INNER JOIN ans.ans_terminologie AS T ON TV.terminologie_ref = T.id
				INNER JOIN ans.ans_jeu_de_valeur_valeur AS JV ON JV.terminologie_valeur_ref = TV.id 
				INNER JOIN ans.ans_jeu_de_valeur AS JA ON JA.id = JV.jeu_de_valeur_ref 
				INNER JOIN ans.ans_profil_version AS PV ON JV.profil_version_ref = PV.id
				INNER JOIN ans.ans_profil AS P ON PV.profil_ref = P.id 
				WHERE TV.code = TM.code AND
				      T.code_system = TM.code_system AND
					  JA.name = J.jeu_de_valeur_ans AND
					  PV.name = @Version AND
					  P.name = @Profil 
			) 
		FROM @TableMapping AS TM,
		     OPENJSON(@JSON) WITH
			 (
				jeu_de_valeur_ans VARCHAR(250) '$.jeuDeValeursANS'
			 ) AS J;


	MERGE ans.mapping AS D
	USING
	(
		SELECT * FROM @TableMapping
	) AS S
	ON	D.kprocess_jeu_de_valeur_ref = @KProcessJeuValeurID AND 
		D.profil_version_ref = @ProfilVersionID AND
		D.ans_jeu_de_valeur_valeur_ref = S.ans_jeu_de_valeur_valeur_ref
	WHEN MATCHED THEN UPDATE SET for_import = S.for_import
	WHEN NOT MATCHED AND S.ans_jeu_de_valeur_valeur_ref IS NOT NULL THEN INSERT(profil_version_ref, kprocess_jeu_de_valeur_ref, kprocess_value, ans_jeu_de_valeur_valeur_ref, for_import) 
						  VALUES(@ProfilVersionID, @KProcessJeuValeurID, S.kprocess_value, S.ans_jeu_de_valeur_valeur_ref, S.for_import)
	WHEN NOT MATCHED BY SOURCE THEN DELETE;
END

GO

CREATE OR ALTER PROCEDURE ans.update_mapping(@File VARCHAR(250))
AS BEGIN
	DECLARE @JSON VARCHAR(MAX);
	DECLARE @Sql NVARCHAR(MAX) = 'SELECT @JSON = CONVERT(VARCHAR(MAX), BulkColumn) FROM OPENROWSET(BULK ''' + @File + ''', SINGLE_BLOB) AS B';
	DECLARE @TableANS TABLE(profile VARCHAR(250), version VARCHAR(250), baseDir VARCHAR(250), filename VARCHAR(250));
	DECLARE @TableMapping TABLE(profile VARCHAR(250), version VARCHAR(250), baseDir VARCHAR(250), filename VARCHAR(250));
	DECLARE @Profil VARCHAR(250);
	DECLARE @Version VARCHAR(250);
	DECLARE @BaseDir VARCHAR(250);
	DECLARE @Filename VARCHAR(250);

	DECLARE AnsIt CURSOR FOR SELECT profile, version, baseDir, filename FROM @TableANS;
	DECLARE MappingIt CURSOR FOR SELECT profile, version, baseDir, filename FROM @TableMapping;

	EXEC sp_executesql @Sql, N'@JSON VARCHAR(MAX) OUTPUT', @JSON = @JSON OUTPUT;

	INSERT INTO @TableANS(profile, version, baseDir, filename)
	SELECT J.profile, J.version, J.baseDir, A.filename
		FROM OPENJSON(@JSON) WITH
		(
			profile VARCHAR(250) '$.profile',
			version VARCHAR(250) '$.version',
			baseDir VARCHAR(250) '$.baseDir',
			ans NVARCHAR(MAX) '$.jeuxDeValeursANS' AS JSON
		) AS J
		CROSS APPLY OPENJSON(J.ans) WITH
		(
			filename VARCHAR(250) '$.file'
		) AS A

	INSERT INTO @TableMapping(profile, version, baseDir, filename)
	SELECT J.profile, J.version, J.baseDir, A.filename

		FROM OPENJSON(@JSON) WITH
		(
			profile VARCHAR(250) '$.profile',
			version VARCHAR(250) '$.version',
			baseDir VARCHAR(250) '$.baseDir',
			mappings NVARCHAR(MAX) '$.mappings' AS JSON
		) AS J
		CROSS APPLY OPENJSON(J.mappings) WITH
		(
			filename VARCHAR(250) '$.file'
		) AS A


	OPEN AnsIt;
	FETCH NEXT FROM AnsIt INTO @Profil, @Version, @BaseDir, @Filename;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @Sql = 'SELECT @JSON = CONVERT(VARCHAR(MAX), BulkColumn) FROM OPENROWSET(BULK ''' + @BaseDir + '\JeuxDeValeurs\' + @Filename + ''', SINGLE_BLOB) AS B';
		EXEC sp_executesql @Sql, N'@JSON VARCHAR(MAX) OUTPUT', @JSON = @JSON OUTPUT;

		EXEC ans.ZSP_update_mapping_jdv @Profil, @Version, @JSON
		FETCH NEXT FROM AnsIt INTO @Profil, @Version, @BaseDir, @Filename;
	END

	CLOSE AnsIt;
	DEALLOCATE AnsIt;

	OPEN MappingIt;
	FETCH NEXT FROM MappingIt INTO @Profil, @Version, @BaseDir, @Filename;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @Sql = 'SELECT @JSON = CONVERT(VARCHAR(MAX), BulkColumn) FROM OPENROWSET(BULK ''' + @BaseDir + '\Mappings\' + @Filename + ''', SINGLE_BLOB) AS B';
		EXEC sp_executesql @Sql, N'@JSON VARCHAR(MAX) OUTPUT', @JSON = @JSON OUTPUT;

		EXEC ans.ZSP_update_mapping_mapping @Profil, @Version, @JSON
		FETCH NEXT FROM MappingIt INTO @Profil, @Version, @BaseDir, @Filename;
	END

	CLOSE MappingIt;
	DEALLOCATE MappingIt;
END

GO

--DECLARE @Xml XML;

--SELECT @Xml = CONVERT(XML, CONVERT(VARCHAR(MAX), BulkColumn)) FROM OPENROWSET(BULK 'D:\Data\ReseauOnco\AAP\JeuxDeValeurs\jdv-morphologie-cisis.xml', SINGLE_BLOB) AS B;

--WITH 
--	XMLNAMESPACES(DEFAULT 'urn:ihe:iti:svs:2008'),
--	CTE AS (
--	SELECT
--		N.x.value('(./@name)[1]', 'VARCHAR(250)') AS name,
--		N.x.value('(./@id)[1]', 'VARCHAR(250)') AS id
--		FROM @Xml.nodes('/RetrieveValueSetResponse/ValueSet') AS N(x)
--	)
--INSERT INTO ans.ans_jeu_de_valeur(name, code_system)
--SELECT J.name, J.id 
--	FROM CTE AS J
--	WHERE NOT EXISTS(SELECT * FROM ans.ans_jeu_de_valeur AS Z WHERE Z.code_system = J.id);


--WITH 
--	XMLNAMESPACES(DEFAULT 'urn:ihe:iti:svs:2008'),
--	CTE AS (
--	SELECT
--		N.x.value('(./@codeSystem)[1]', 'VARCHAR(250)') AS code_system
--		FROM @Xml.nodes('/RetrieveValueSetResponse/ValueSet/ConceptList/Concept') AS N(x)
--	)
--INSERT INTO ans.ans_terminologie(code_system)
--SELECT DISTINCT J.code_system
--	FROM CTE AS J
--	WHERE NOT EXISTS(SELECT * FROM ans.ans_terminologie AS Z WHERE Z.code_system = J.code_system);

--WITH 
--	XMLNAMESPACES(DEFAULT 'urn:ihe:iti:svs:2008'),
--	CTE AS (
--	SELECT
--		N.x.value('(./@codeSystem)[1]', 'VARCHAR(250)') AS code_system,
--		N.x.value('(./@code)[1]', 'VARCHAR(250)') AS code,
--		N.x.value('(./@displayName)[1]', 'VARCHAR(250)') AS display_name
--		FROM @Xml.nodes('/RetrieveValueSetResponse/ValueSet/ConceptList/Concept') AS N(x)
--	)
--INSERT INTO ans.ans_terminologie_valeur(terminologie_ref, code, display_name)
--SELECT DISTINCT 
--	T.id,
--	J.code,
--	J.display_name
--	FROM CTE AS J
--	INNER JOIN ans.ans_terminologie AS T ON T.code_system = J.code_system
--	WHERE NOT EXISTS(SELECT * FROM ans.ans_terminologie_valeur AS Z WHERE Z.terminologie_ref = T.id AND Z.code = J.code)

