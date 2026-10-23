CREATE SCHEMA ans;
GO
CREATE TABLE ans.ans_terminologie
(
	id BIGINT IDENTITY NOT NULL,
	code_system VARCHAR(250) NOT NULL,
	name VARCHAR(250),
	CONSTRAINT PK_ans__ans_terminologie PRIMARY KEY (id),
	CONSTRAINT UK_ans__ans_terminologie UNIQUE(code_system)
)

CREATE TABLE ans.ans_terminologie_valeur
(
	id BIGINT IDENTITY NOT NULL,
	terminologie_ref BIGINT NOT NULL,
	code VARCHAR(250) NOT NULL,
	display_name VARCHAR(250) NOT NULL,
	CONSTRAINT PK_ans__ans_terminologie_valeur PRIMARY KEY(id),
	CONSTRAINT FK_ans__ans_terminologie_valeur FOREIGN KEY(terminologie_ref) REFERENCES ans.ans_terminologie(id),
	CONSTRAINT UK_ans__ans_terminologie_valeur UNIQUE(terminologie_ref, code) 
)


CREATE TABLE ans.ans_profil
(
	id BIGINT IDENTITY NOT NULL,
	name VARCHAR(250) NOT NULL,
	CONSTRAINT PK_ans__ans_profil PRIMARY KEY(id),
	CONSTRAINT UK_ans__ans_profil UNIQUE(name)
)

CREATE TABLE ans.ans_profil_version
(
	id BIGINT IDENTITY NOT NULL,
	profil_ref BIGINT NOT NULL,
	name VARCHAR(250) NOT NULL,
	CONSTRAINT PK_ans__ans_profil_version PRIMARY KEY(id),
	CONSTRAINT UK_ans__ans_profil_version UNIQUE(profil_ref, name),
	CONSTRAINT FK_ans__ans_profil_version FOREIGN KEY(profil_ref) REFERENCES ans.ans_profil(id)
)


CREATE TABLE ans.ans_jeu_de_valeur
(
	id BIGINT IDENTITY NOT NULL,
	code_system VARCHAR(250) NOT NULL,
	name VARCHAR(250) NOT NULL,
	CONSTRAINT PK_ans__ans_jeu_de_valeur PRIMARY KEY(id),
	CONSTRAINT UK_ans__ans_jeu_de_valeur__code_system UNIQUE(code_system),
	CONSTRAINT UK_ans__ans_jeu_de_valeur__name UNIQUE(name)
)

CREATE TABLE ans.ans_jeu_de_valeur_valeur
(
	id BIGINT IDENTITY NOT NULL,
	jeu_de_valeur_ref BIGINT NOT NULL,
	terminologie_valeur_ref BIGINT NOT NULL,
	profil_version_ref BIGINT NOT NULL,
	CONSTRAINT PK_ans__ans_jeu_de_valeur_valeur PRIMARY KEY(id),
	CONSTRAINT FK_ans__ans_jeu_de_valeur_valeur__jeu_de_valeur_ref FOREIGN KEY(jeu_de_valeur_ref) REFERENCES ans.ans_jeu_de_valeur(id),
	CONSTRAINT FK_ans__ans_jeu_de_valeur_valeur__terminologie_valeur_ref FOREIGN KEY(terminologie_valeur_ref) REFERENCES ans.ans_terminologie_valeur(id),
	CONSTRAINT FK_ans__ans_jeu_de_valeur_valeur__profil_version_ref FOREIGN KEY(profil_version_ref) REFERENCES ans.ans_profil_version(id),
	CONSTRAINT UK_ans__ans_jeu_de_valeur_valeur UNIQUE(profil_version_ref, terminologie_valeur_ref) 
)

CREATE TABLE ans.kprocess_jeu_de_valeur
(
	id BIGINT IDENTITY NOT NULL,
	name VARCHAR(250) NOT NULL,
	table_name VARCHAR(250) NOT NULL,
	CONSTRAINT PK_ans__kprocess_jeu_de_valeur PRIMARY KEY(id),
	CONSTRAINT UK_ans__kprocess_jeu_de_valeur UNIQUE(name)
)

CREATE TABLE ans.ZT_mapping
(
	id BIGINT IDENTITY NOT NULL,
	profil_version_ref BIGINT NOT NULL,
	kprocess_jeu_de_valeur_ref BIGINT NOT NULL,
	kprocess_value VARCHAR(50) NOT NULL,
	kprocess_id INT,
	kprocess_label VARCHAR(250),
	for_import BIT NOT NULL,
	ans_jeu_de_valeur_valeur_ref BIGINT NOT NULL,
	valid_from DATETIME2 NULL,
	valid_to DATETIME2 NULL,
	CONSTRAINT PK_ans__ZT_mapping PRIMARY KEY(id),
	CONSTRAINT FK_ans__ZT_mapping__kprocess_jeu_de_valeur_ref FOREIGN KEY(kprocess_jeu_de_valeur_ref) REFERENCES ans.kprocess_jeu_de_valeur(id),
	CONSTRAINT FK_ans__ZT_mapping__ans_jeu_de_valeur_valeur_ref FOREIGN KEY(ans_jeu_de_valeur_valeur_ref) REFERENCES ans.ans_jeu_de_valeur_valeur(id),
	CONSTRAINT FK_ans__ZT_mapping__profil_version_ref FOREIGN KEY(profil_version_ref) REFERENCES ans.ans_profil_version(id),	
)

CREATE UNIQUE INDEX UK_ans__ZT_mapping ON ans.ZT_mapping(profil_version_ref, kprocess_jeu_de_valeur_ref, kprocess_value) WHERE for_import = 1
CREATE UNIQUE INDEX UK_ans__ZT_mapping__ans_jeu_de_valeur_valeur_ref ON ans.ZT_mapping(profil_version_ref, kprocess_jeu_de_valeur_ref, kprocess_value, ans_jeu_de_valeur_valeur_ref) 
GO

ALTER TABLE core.sexe_enum
ADD code AS (value);

--ALTER TABLE dbo.etablissements_practice_settings_enum
--ADD code AS (value);

ALTER TABLE account.profil_professionnel_sante_titre_enum
ADD code AS (value);

ALTER TABLE dbo.fiches_rcp_v1_capacite_oms_enum
ADD value AS (code);

ALTER TABLE dbo.etablissements_type_enum
ADD value AS (code);

ALTER TABLE dbo.tumeur_enum
ADD value AS (code);


GO

CREATE OR ALTER VIEW ans.mapping
AS
	SELECT 
		M.id,
		M.profil_version_ref,
		P.name AS 'profil',
		PV.name AS 'version',
		M.kprocess_jeu_de_valeur_ref, 
		KJ.name AS 'kprocess_name',
		KJ.table_name AS 'kprocess_table',
		M.kprocess_value,
		M.kprocess_id,
		M.kprocess_label,
		M.ans_jeu_de_valeur_valeur_ref,
		TV.code,
		T.code_system,
		TV.display_name,
		M.for_import
		FROM ans.ZT_mapping AS M
		INNER JOIN ans.ans_profil_version AS PV ON M.profil_version_ref = PV.id
		INNER JOIN ans.ans_profil AS P ON PV.profil_ref = P.id
		INNER JOIN ans.kprocess_jeu_de_valeur AS KJ ON KJ.id = M.kprocess_jeu_de_valeur_ref
		INNER JOIN ans.ans_jeu_de_valeur_valeur AS AVV ON M.ans_jeu_de_valeur_valeur_ref = AVV.id
		INNER JOIN ans.ans_jeu_de_valeur AS AV ON AVV.jeu_de_valeur_ref = AV.id 
		INNER JOIN ans.ans_terminologie_valeur AS TV ON AVV.terminologie_valeur_ref = TV.id 
		INNER JOIN ans.ans_terminologie AS T ON TV.terminologie_ref = T.id 
GO

CREATE OR ALTER VIEW ans.kprocess_value
AS
	SELECT 'TypeFichier' AS jeu_de_valeur, FT.value, FT.label FROM dbo.fichiers_type_enum AS FT
	UNION SELECT 'T', value, label FROM dbo.T_enum
	UNION SELECT 'N', value, label FROM dbo.N_enum
	UNION SELECT 'M', value, label FROM dbo.M_enum
	UNION SELECT 'CIM10', code_cim, label FROM dbo.tumeur_enum

GO
INSERT INTO ans.ans_profil(name) 
SELECT 
	V.name
	FROM (VALUES ('FicheRCP')) AS V(name)
	WHERE NOT EXISTS (SELECT * FROM ans.ans_profil AS Z WHERE Z.name = V.name);

INSERT INTO ans.ans_profil_version(profil_ref, name)
SELECT 
	P.id,
	V.name
	FROM (VALUES ('FicheRCP', '2025.1')) AS V(profil, name)
	INNER JOIN ans.ans_profil AS P ON P.name = V.profil
	WHERE NOT EXISTS (SELECT * FROM ans.ans_profil_version AS Z WHERE Z.name = V.name AND Z.profil_ref = P.id);

GO


ALTER TABLE ans.ans_jeu_de_valeur_valeur DROP CONSTRAINT UK_ans__ans_jeu_de_valeur_valeur
GO

ALTER TABLE ans.ans_jeu_de_valeur_valeur ADD  CONSTRAINT [UK_ans__ans_jeu_de_valeur_valeur] UNIQUE NONCLUSTERED 
(
	[profil_version_ref] ASC,
	[terminologie_valeur_ref] ASC,
	[jeu_de_valeur_ref] ASC
)
GO

DROP INDEX UK_ans__ZT_mapping ON ans.ZT_mapping
GO

CREATE UNIQUE NONCLUSTERED INDEX UK_ans__ZT_mapping ON ans.ZT_mapping
(
	[profil_version_ref] ASC,
	[kprocess_jeu_de_valeur_ref] ASC,
	[kprocess_value] ASC
)
WHERE ([for_import]=(1))
GO





GO





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
CREATE OR ALTER PROCEDURE [ans].[ZSP_update_mapping_mapping](@Profil VARCHAR(250), @Version VARCHAR(250), @JSON VARCHAR(MAX))
AS BEGIN 
	DECLARE @TableMapping TABLE(kprocess_value VARCHAR(50), kprocess_id INT, kprocess_label VARCHAR(250), for_import BIT, ans_jeu_de_valeur_valeur_ref BIGINT, code VARCHAR(250), code_system VARCHAR(250));
	DECLARE @ProfilVersionID BIGINT;
	DECLARE @KProcessJeuValeurID BIGINT;
	DECLARE @TableKProcessJeuDeValeurs TABLE(id INT, value VARCHAR(50), label VARCHAR(250))
	DECLARE @TableName VARCHAR(250);
	DECLARE @SQL NVARCHAR(MAX);

	SELECT @ProfilVersionID = PV.id 
		FROM ans.ans_profil_version AS PV
		INNER JOIN ans.ans_profil AS P ON PV.profil_ref = P.id
		WHERE P.name = @Profil AND PV.name = @Version;

	-- Cr�ation des jeux de valeur si n�cessaire
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
	MERGE ans.kprocess_jeu_de_valeur AS D
	USING 
	(
		SELECT J.name, J.table_name FROM CTE AS J		
	) AS S
	ON S.name = D.name
	WHEN NOT MATCHED THEN INSERT(name, table_name) VALUES (S.name, S.table_name)
	WHEN MATCHED THEN UPDATE SET table_name = S.table_name;

	SELECT @KProcessJeuValeurID = id,
		   @TableName = KJV.table_name
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
				ignore BIT '$.ignore',
                to_delete BIT '$.toDelete',
                move_to VARCHAR(250) '$.moveTo'
			) AS M
    WHERE COALESCE(M.ignore, 0) = 0 AND
          COALESCE(M.to_delete, 0) = 0 AND
          COALESCE(M.move_to, '') = '';

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
				additional_values NVARCHAR(MAX) '$.additionalValues' AS JSON,
                to_delete BIT '$.toDelete',
                move_to VARCHAR(250) '$.moveTo'
			) AS M
			CROSS APPLY OPENJSON(M.additional_values) WITH
			(
				code VARCHAR(250) '$.code',
				code_system VARCHAR(250) '$.codeSystem'
			) AS V
                WHERE COALESCE(M.ignore, 0) = 0 AND
                      COALESCE(M.to_delete, 0) = 0 AND
                      COALESCE(M.move_to, '') = '';


	
	-- Résolution des valeurs présentes dans la table K-Process	
	SET @SQL = 'SELECT id, value, label FROM ' + @TableName;
	INSERT INTO @TableKProcessJeuDeValeurs(id, value, label) 
	EXEC sp_executesql @Sql;

	UPDATE TM
		SET kprocess_id = J.id,
		    kprocess_label = J.label
		FROM @TableMapping AS TM
		INNER JOIN @TableKProcessJeuDeValeurs AS J ON J.value = TM.kprocess_value

	-- R�solution de ans_jeu_de_valeur_valeur_ref
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


    IF EXISTS(SELECT * FROM @TableMapping WHERE ans_jeu_de_valeur_valeur_ref IS NULL)
    BEGIN
        SELECT * FROM @TableMapping WHERE ans_jeu_de_valeur_valeur_ref IS NULL;
        THROW 50000, 'Mapping incomplet : impossible de trouver le jeu de valeur ANS correspondant pour les valeurs suivantes (cf. table retournée)', 0
    END

	MERGE ans.ZT_mapping AS D
	USING
	(
		SELECT * FROM @TableMapping
	) AS S
	ON	D.kprocess_jeu_de_valeur_ref = @KProcessJeuValeurID AND 
		D.profil_version_ref = @ProfilVersionID AND
		D.ans_jeu_de_valeur_valeur_ref = S.ans_jeu_de_valeur_valeur_ref
	WHEN MATCHED THEN UPDATE SET for_import = S.for_import,
								 kprocess_id = S.kprocess_id,
								 kprocess_label = S.kprocess_label
	WHEN NOT MATCHED AND S.ans_jeu_de_valeur_valeur_ref IS NOT NULL THEN INSERT(profil_version_ref, kprocess_jeu_de_valeur_ref, kprocess_value, kprocess_id, kprocess_label, ans_jeu_de_valeur_valeur_ref, for_import) 
						  VALUES(@ProfilVersionID, @KProcessJeuValeurID, S.kprocess_value, S.kprocess_id, S.kprocess_label, S.ans_jeu_de_valeur_valeur_ref, S.for_import)
	WHEN NOT MATCHED BY SOURCE AND 
			kprocess_jeu_de_valeur_ref = @KProcessJeuValeurID AND 
			profil_version_ref = @ProfilVersionID THEN DELETE;
END

GO
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
		PRINT 'XML : Chargement de ' + @FileName;
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
		PRINT 'JSON : Chargement de ' + @Filename;
		SET @Sql = 'SELECT @JSON = CONVERT(VARCHAR(MAX), BulkColumn) FROM OPENROWSET(BULK ''' + @BaseDir + '\Mappings\' + @Filename + ''', SINGLE_BLOB) AS B';
		EXEC sp_executesql @Sql, N'@JSON VARCHAR(MAX) OUTPUT', @JSON = @JSON OUTPUT;

		EXEC ans.ZSP_update_mapping_mapping @Profil, @Version, @JSON
		FETCH NEXT FROM MappingIt INTO @Profil, @Version, @BaseDir, @Filename;
	END

	CLOSE MappingIt;
	DEALLOCATE MappingIt;
END

GO











CREATE OR ALTER   PROCEDURE [dbo].[comparer_mapping_KProcess_ANS]
	--@JsonSource = path du fichier jeuxDeValeurs.json
	@JsonSource NVARCHAR(500),
	--@DatabaseName = par exemple : 'OncoPC_DCC_test'
	@DatabaseName SYSNAME

	AS
	BEGIN

		SET NOCOUNT ON;

		DECLARE @NomDeFichierJson AS NVARCHAR (MAX);
		DECLARE @NomDeFichierXml AS NVARCHAR(MAX);
		DECLARE @Json AS NVARCHAR (MAX);
		DECLARE @Profile AS NVARCHAR (MAX);
		DECLARE @Version AS NVARCHAR (MAX);
		DECLARE @Name AS NVARCHAR (500);
		DECLARE @IgnoredValues AS NVARCHAR(MAX);
		DECLARE @MonSql AS NVARCHAR (MAX);
		DECLARE @SqlToMap AS NVARCHAR (MAX);
		DECLARE @SqlToInsert AS NVARCHAR (MAX);
		DECLARE @SqlExtraValues AS NVARCHAR (MAX);
		DECLARE @SqlMoveTo AS NVARCHAR(MAX);
		DECLARE @SqlDoppelganger AS NVARCHAR(MAX);
		DECLARE @Table AS SYSNAME;
		DECLARE @JdvAns AS NVARCHAR (MAX);
		DECLARE @JsonCursor AS NVARCHAR (MAX);
		DECLARE @PathJson AS NVARCHAR (MAX);
		DECLARE @PathJsonfile AS NVARCHAR(MAX);
		DECLARE @PathXml AS NVARCHAR(MAX);
		DECLARE @PathXmlFile AS NVARCHAR(MAX);
		DECLARE @MonXml AS NVARCHAR(MAX);
		DECLARE @XmlTable AS TABLE(nom VARCHAR(250), filename VARCHAR(500), xml NVARCHAR(MAX));
		DECLARE @XmlCursor AS VARCHAR (MAX);
		DECLARE @NomJeuDeValeur NVARCHAR(MAX);

		DROP TABLE IF EXISTS #anomalies;
		CREATE TABLE #anomalies (
			profil              NVARCHAR (MAX),
			version             NVARCHAR (250),
			fichier_json_name   NVARCHAR (MAX),
			name                NVARCHAR (500),
			table_name          SYSNAME       ,
			jeux_de_valeurs_name NVARCHAR (MAX),
			j_kprocess          NVARCHAR (MAX),
			j_code				NVARCHAR (MAX),
			j_code_system		NVARCHAR (MAX),
			j_ignored_values	NVARCHAR (MAX),
			j_additional_values NVARCHAR (MAX),
			k_values		    NVARCHAR (MAX),
			k_code				NVARCHAR (MAX),
			x_code				NVARCHAR (MAX),
			x_code_system		NVARCHAR (MAX),
			is_ignored          BIT DEFAULT 0,
			value_to_map        BIT DEFAULT 0,
			extra_value         BIT DEFAULT 0,
			to_insert           BIT DEFAULT 0, 
			to_delete			BIT DEFAULT 0,
			move_to				NVARCHAR (MAX),
			doppelganger		BIT DEFAULT 0
		);

		-- Table temporaire pour stocker le contenu du XML
		DROP TABLE IF EXISTS #valeurs_xml_ans;
		CREATE TABLE #valeurs_xml_ans (
			x_code        NVARCHAR(250),
			x_code_system NVARCHAR(500)
		);

		-- Acces au JSON jeuxDeValeurs
		SET @MonSql = N'
			DECLARE @JsonBinary VARBINARY(MAX);
			SELECT @JsonBinary = BulkColumn
			FROM OPENROWSET(BULK '''+@JsonSource+''', SINGLE_BLOB) AS source;
			DECLARE @temp TABLE (val VARCHAR(MAX) COLLATE French_100_CI_AS_SC_UTF8);
            INSERT INTO @temp (val) SELECT @JsonBinary;
            SELECT @Json = CONVERT(NVARCHAR(MAX), val) FROM @temp;					
			';

		EXECUTE sp_executesql @MonSql, N'@Json NVARCHAR(MAX) OUTPUT', @Json = @Json OUTPUT;
		
		--Recuperation des valeurs globales du JSON jeuxDeValeurs et du chemin de chaque fichier de mapping
		SELECT @Profile = profil,
			   @Version = version,
			   @PathJson = pathJSON,
			   @PathXml = pathJSON
		FROM OPENJSON (@Json) WITH (
			profil NVARCHAR (MAX) '$.profile',
			version NVARCHAR (MAX) '$.version',
			pathJSON NVARCHAR (MAX) '$.baseDir'
			);

		SET @PathJson = @PathJson + '\Mappings\';

		SET @PathXml = @PathXml + '\JeuxDeValeurs\';
				
		-- Creation de curseur pour avancer dans les noms de chaque fichier XML de l'ANS 
		DECLARE foreachANS CURSOR LOCAL FAST_FORWARD
			FOR SELECT fichier, nom
				FROM OPENJSON (@Json, '$.jeuxDeValeursANS') 
				WITH (fichier NVARCHAR (MAX) '$.file', nom NVARCHAR(MAX) '$.name');

		OPEN foreachANS;

		FETCH NEXT FROM foreachANS INTO @NomDeFichierXml, @NomJeuDeValeur;
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @PathXmlfile = @PathXml + @NomDeFichierXml;
			
			--Lecture du fichier XML ANS specifique à chaque jeu de valeur
			SET @MonSql = N'
				DECLARE @XmlBinary VARBINARY(MAX);
				SELECT @XmlBinary = BulkColumn
				FROM OPENROWSET(BULK ''' + @PathXmlfile + ''', SINGLE_BLOB) AS sourceXML;
				SELECT @XmlCursor = CONVERT(VARCHAR(MAX), @XmlBinary);		
				';

			PRINT 'Chargement fichier XML ' + @PathXmlFile;
			EXECUTE sp_executesql @MonSql, N'@XmlCursor VARCHAR(MAX) OUTPUT', @XmlCursor = @XmlCursor OUTPUT;			

			
			INSERT INTO @XmlTable(nom, filename, xml) 
			SELECT
				@NomJeuDeValeur,
				@PathXmlfile, 
				@XmlCursor
			FETCH NEXT FROM foreachANS INTO @NomDeFichierXml, @NomJeuDeValeur;
			
		END
		--SELECT * FROM @XmlTable;

		--Creation de curseur pour naviguer dans chaque fichier json de mapping
		DECLARE foreach CURSOR LOCAL FAST_FORWARD
			FOR SELECT fichier
				FROM OPENJSON (@Json, '$.mappings') WITH (fichier NVARCHAR (MAX) '$.file');

		OPEN foreach;

		FETCH NEXT FROM foreach INTO @NomDeFichierJson;

		WHILE @@FETCH_STATUS = 0
			BEGIN
			
				SET @PathJsonfile = @PathJson + @NomDeFichierJson;
				PRINT 'pathJson : ' + @PathJsonfile;
				--Lecture du fichier JSON specifique à chaque jeu de valeur
				SET @MonSql = N'
					DECLARE @JsonBinary VARBINARY(MAX);
					SELECT @JsonBinary = BulkColumn
					FROM OPENROWSET(BULK ''' + @PathJsonfile + ''', SINGLE_BLOB) AS sourceJSON;
					DECLARE @temp TABLE (val VARCHAR(MAX) COLLATE French_100_CI_AS_SC_UTF8);
                    INSERT INTO @temp (val) SELECT @JsonBinary;
                    SELECT @JsonCursor = CONVERT(NVARCHAR(MAX), val) FROM @temp;		
					';
				EXECUTE sp_executesql @MonSql, N'@JsonCursor NVARCHAR(MAX) OUTPUT', @JsonCursor = @JsonCursor OUTPUT;

				SET @NomDeFichierXml = NULL;
				
				SELECT @nomDeFichierXml = X.filename
					FROM @XmlTable AS X,
						OPENJSON (@JsonCursor) WITH (fichierXML NVARCHAR (MAX) '$.jeuDeValeursANS') AS J
					WHERE X.nom = J.fichierXML
				IF @nomDeFichierXml IS NULL
					BEGIN
						PRINT 'Aucun élément trouvé pour le fichier XML.';
					END
					ELSE
					BEGIN
						PRINT 'nomDeFichierXml : '+@nomDeFichierXml; 
						SET @PathXmlFile = @NomDeFichierXml --+ '.xml';
					END
				
				
				TRUNCATE TABLE #valeurs_xml_ans;

				--Recuperation des données du jeu de valeur XML dans une tableau temporaire #valeurs_xml_ans
				SET @MonXml = N'
					DECLARE @xml XML;
					SELECT @xml = CAST(BulkColumn AS XML)
					FROM OPENROWSET(BULK '''+@PathXmlFile+''', SINGLE_BLOB) AS sourceXML;
					WITH XMLNAMESPACES (''urn:ihe:iti:svs:2008'' AS ns)
					INSERT INTO #valeurs_xml_ans (x_code, x_code_system)
					SELECT
						concept.value(''@code'',        ''NVARCHAR(250)'')    AS x_code,
						concept.value(''@codeSystem'', ''NVARCHAR(500)'')  AS x_code_system
					FROM @xml.nodes(''/ns:RetrieveValueSetResponse/ns:ValueSet/ns:ConceptList/ns:Concept'') AS ANS(concept);
					';
					EXECUTE sp_executesql @MonXml;
				 
				--Assignation des valeurs specifiques du JSON aux variables @Table, @JdvAns, @Name et @IgnoredValues
				SELECT @Table = tableName, @JdvAns = jeuDeValeursANS, @Name = name, @IgnoredValues = ignoredValues
				FROM OPENJSON (@JsonCursor) WITH (
					tableName NVARCHAR (MAX) '$.tableName',
					jeuDeValeursANS NVARCHAR (MAX) '$.jeuDeValeursANS',
					name NVARCHAR (500) '$.name',
					ignoredValues NVARCHAR(MAX) '$.ignoresValues' AS JSON);

				SET @SqlExtraValues = N'
					WITH recapExtraValues AS(
						SELECT 
							J.j_kprocess, 
							J.j_code, 
							J.j_code_system,
							J.j_toDelete,
							J.j_moveTo,
							COALESCE(J.is_ignored, 0) AS is_ignored,
							K.value AS k_values, 
							K.code AS k_code
						FROM OPENJSON(@JsonCursor, ''$.mapping'') 
							WITH (
								j_kprocess NVARCHAR(MAX) ''$.kprocess'', 
								j_code NVARCHAR(MAX) ''$.code'',
								j_code_system NVARCHAR(500) ''$.codeSystem'',
								j_toDelete NVARCHAR(500) ''$.toDelete'',
								j_moveTo NVARCHAR(MAX) ''$.moveTo'',
								is_ignored BIT ''$.ignore''
							) AS J
						FULL JOIN ' + @DatabaseName + '.' + @Table + ' AS K ON REPLACE(K.value,''.'','''') = REPLACE(J.j_kprocess, ''.'','''') 
						WHERE J.j_moveTo IS NULL)
						INSERT INTO #anomalies (profil, version, fichier_json_name, name, table_name, jeux_de_valeurs_name,
												j_kprocess, j_code, j_code_system,
												k_values, k_code, is_ignored, extra_value, to_delete)
							SELECT
								@Profile,
								@Version,
								@NomDeFichierJson, 
								@Name,
								@Table, 
								@JdvAns,
								j_kprocess,
								j_code, 
								j_code_system,
								k_values,
								k_code,
								is_ignored,
								CASE WHEN (k_values IS NOT NULL OR k_values !='''')
									AND (j_kprocess IS NULL OR j_code IS NULL)
									AND is_ignored = 0
									THEN 1 ELSE 0 
									END,
								CASE WHEN LOWER(TRIM(j_toDelete)) = ''true'' THEN 1 ELSE 0 END
							FROM recapExtraValues AS REV
							WHERE k_values IS NOT NULL
								AND (j_code IS NULL OR j_kprocess IS NULL)
								AND is_ignored = 0
								OR LOWER(TRIM(j_toDelete)) = ''true''
								; 
							';
				EXECUTE sp_executesql @SqlExtraValues, N'@JsonCursor NVARCHAR(MAX),
														@Profile NVARCHAR(MAX), 
														@Version NVARCHAR(MAX),
														@NomDeFichierJson NVARCHAR(MAX), 
														@Name NVARCHAR(500),
														@Table SYSNAME, 
														@JdvAns NVARCHAR(MAX)', 
														@JsonCursor = @JsonCursor, 
														@Profile = @Profile,
														@Version = @Version,
														@NomDeFichierJson = @NomDeFichierJson,
														@Name = @Name, 
														@Table = @Table,  
														@JdvAns = @JdvAns;

				SET @SqlToInsert = N'
							WITH recapToInsert AS(
								SELECT 
									J.j_kprocess, 
									J.j_code, 
									J.j_code_system,
									COALESCE(J.is_ignored, 0) AS is_ignored,
									J.j_additional_values,
									J.j_toDelete,
									K.value AS k_values, 
									K.code AS k_code
								FROM OPENJSON(@JsonCursor, ''$.mapping'') 
								WITH (
									j_kprocess NVARCHAR(MAX) ''$.kprocess'', 
									j_code NVARCHAR(MAX) ''$.code'',
									j_code_system NVARCHAR(500) ''$.codeSystem'',
									j_toDelete NVARCHAR(500) ''$.toDelete'',
									is_ignored BIT ''$.ignore'',
									j_additional_values NVARCHAR(MAX) ''$.additionalValues'' AS JSON
									) AS J
						
								FULL JOIN ' + @DatabaseName + '.' + @Table + ' AS K ON REPLACE(K.value,''.'','''') = REPLACE(J.j_kprocess, ''.'', '''')
							)
							INSERT INTO #anomalies(profil, version, fichier_json_name, name, table_name, jeux_de_valeurs_name, 
													j_kprocess, j_code, j_code_system,
													k_values, k_code, 
													is_ignored, to_insert, to_delete)
								SELECT
									@Profile,
									@Version,
									@NomDeFichierJson, 
									@Name,
									@Table, 
									@JdvAns,
									j_kprocess,
									j_code, 
									j_code_system,
									k_values,
									k_code,
									is_ignored,
									CASE WHEN (k_values IS NULL OR k_values ='''') 
											AND COALESCE(is_ignored, 0) = 0 
											AND (j_kprocess IS NOT NULL OR j_code IS NOT NULL)
												THEN 1 ELSE 0 END,
									CASE WHEN LOWER(TRIM(j_toDelete)) = ''true'' THEN 1 ELSE 0 END
								FROM recapToInsert AS RTI
								WHERE k_values IS NULL OR k_values = '''';
							';
				EXECUTE sp_executesql @SqlToInsert, N'@JsonCursor NVARCHAR(MAX),
													@Profile NVARCHAR(MAX), 
													@Version NVARCHAR(MAX),
													@NomDeFichierJson NVARCHAR(MAX), 
													@Name NVARCHAR(500),
													@Table SYSNAME, 
													@JdvAns NVARCHAR(MAX)', 
													@JsonCursor = @JsonCursor, 
													@Profile = @Profile,
													@Version = @Version,
													@NomDeFichierJson = @NomDeFichierJson,
													@Name = @Name, 
													@Table = @Table,  
													@JdvAns = @JdvAns;

				SET @SqlToMap = N'
					DROP TABLE IF EXISTS #ignoresValues;
					CREATE TABLE #ignoresValues(
						i_code NVARCHAR(50),
						i_code_system NVARCHAR(50)
					);
					INSERT INTO #ignoresValues (i_code, i_code_system)
						SELECT 
							i_code, 
							i_code_system
						FROM OPENJSON(@IgnoredValues)
						WITH (
							i_code NVARCHAR(MAX) ''$.code'',
							i_code_system NVARCHAR(500) ''$.codeSystem''
						);
					
					DROP TABLE IF EXISTS #jsonValues;
					CREATE TABLE #jsonValues(
						j_jdv_ANS NVARCHAR(MAX),
						j_kprocess NVARCHAR(50),
						j_code NVARCHAR(50), 
						j_code_system NVARCHAR(50),
						adv_code NVARCHAR(50), 
						adv_code_system NVARCHAR(50),
						to_ignore BIT
					);
					INSERT INTO #jsonValues(j_jdv_ANS,j_kprocess, j_code, j_code_system, adv_code, adv_code_system, to_ignore)
					SELECT @JdvAns,
						j.kprocess,
						j.code, 
						j.code_system,
						adv.code, 
						adv.code_system,
						ISNULL(j.ignore, CAST(0 AS BIT)) AS to_ignore
					FROM OPENJSON(@JsonCursor, ''$.mapping'')
					WITH (
						kprocess NVARCHAR(50) ''$.kprocess'',
						code NVARCHAR(50) ''$.code'',
						code_system NVARCHAR(50) ''$.codeSystem'',
						ignore BIT ''$.ignore'',
						additional_values NVARCHAR(MAX) ''$.additionalValues'' AS JSON
					)j
					OUTER APPLY OPENJSON(j.additional_values)
					WITH (
						code NVARCHAR(50) ''$.code'',
						code_system NVARCHAR(50) ''$.codeSystem''
						) adv;

					
					DROP TABLE IF EXISTS #recap;
					CREATE TABLE #recap(
						j_kprocess NVARCHAR(500),
						j_code NVARCHAR(500),
						j_code_system NVARCHAR(500),
						j_is_ignored BIT,
						adv_code NVARCHAR(500),
						adv_code_system NVARCHAR(500),
						x_code NVARCHAR(50),
						x_code_system NVARCHAR(50),
						i_code NVARCHAR(500),
						i_code_system NVARCHAR(500)
					);

					INSERT INTO #recap(j_kprocess, j_code, j_code_system, j_is_ignored, adv_code, adv_code_system, x_code, x_code_system, i_code, i_code_system)
						SELECT J.j_kprocess, 
							J.j_code, 
							J.j_code_system, 
							J.to_ignore,
							J.adv_code,
							J.adv_code_system,
							X.x_code, 
							X.x_code_system, 
							I.i_code,
							I.i_code_system
						FROM #jsonValues AS J
						FULL JOIN #valeurs_xml_ans AS X ON X.x_code = J.j_code
						LEFT JOIN #ignoresValues AS I ON X.x_code = I.i_code
						WHERE (J.to_ignore = 0 OR J.to_ignore IS NULL)
						AND (j_code IS NULL AND x_code IS NOT NULL)
						AND x_code NOT IN (SELECT i_code FROM #ignoresValues WHERE i_code IS NOT NULL) 
						AND x_code NOT IN (SELECT adv_code FROM #jsonValues WHERE adv_code IS NOT NULL)
						


						INSERT INTO #anomalies(profil, version, fichier_json_name, name, table_name, jeux_de_valeurs_name, 
											j_kprocess, j_code, j_code_system, j_ignored_values, j_additional_values,
											x_code, x_code_system,
											value_to_map)
						SELECT
							@Profile,
							@Version,
							@NomDeFichierJson, 
							@Name,
							@Table, 
							@JdvAns,
							R.j_kprocess, 
							R.j_code, 
							R.j_code_system, 
							R.j_is_ignored,
							R.adv_code,
							R.x_code, 
							R.x_code_system, 
							''1''
						FROM #recap AS R;
				';
				EXECUTE sp_executesql @SqlToMap, N'@JsonCursor NVARCHAR(MAX),
													@Profile NVARCHAR(MAX), 
													@Version NVARCHAR(MAX),
													@NomDeFichierJson NVARCHAR(MAX), 
													@Name NVARCHAR(500),
													@Table SYSNAME, 
													@JdvAns NVARCHAR(MAX), 
													@IgnoredValues NVARCHAR(MAX)',
													@JsonCursor = @JsonCursor, 
													@Profile = @Profile,
													@Version = @Version,
													@NomDeFichierJson = @NomDeFichierJson,
													@Name = @Name, 
													@Table = @Table,  
													@JdvAns = @JdvAns,
													@IgnoredValues = @IgnoredValues
													;

				SET @SqlMoveTo = N'
					WITH recapToMove AS(
						SELECT 
							J.j_kprocess,
							J.j_moveTo,
							K.value AS k_values, 
							K.code AS k_code
						FROM OPENJSON(@JsonCursor, ''$.mapping'') 
						WITH (
							j_kprocess NVARCHAR(MAX) ''$.kprocess'',
							j_moveTo NVARCHAR(MAX) ''$.moveTo''
							) AS J
						FULL JOIN ' + @DatabaseName + '.' + @Table + ' AS K ON REPLACE(K.value, ''.'', '''') = REPLACE(J.j_kprocess, ''.'', '''')
						LEFT JOIN ' + @DatabaseName + '.' + @Table + ' AS K2 ON REPLACE(K.value, ''.'', '''') = REPLACE(j_moveTo, ''.'', '''')
						)
							INSERT INTO #anomalies(profil, version, fichier_json_name, name, table_name, jeux_de_valeurs_name, 
													j_kprocess,
													k_values, k_code, 
													move_to)
								SELECT
									@Profile,
									@Version,
									@NomDeFichierJson, 
									@Name,
									@Table, 
									@JdvAns,
									j_kprocess,
									k_values,
									k_code,
									j_moveTo								
								FROM recapToMove AS RTM
								WHERE j_moveTo IS NOT NULL;				
								';
				EXECUTE sp_executesql @SqlMoveTo, N'@JsonCursor NVARCHAR(MAX),
													@Profile NVARCHAR(MAX), 
													@Version NVARCHAR(MAX),
													@NomDeFichierJson NVARCHAR(MAX), 
													@Name NVARCHAR(500),
													@Table SYSNAME, 
													@JdvAns NVARCHAR(MAX), 
													@IgnoredValues NVARCHAR(MAX)',
													@JsonCursor = @JsonCursor, 
													@Profile = @Profile,
													@Version = @Version,
													@NomDeFichierJson = @NomDeFichierJson,
													@Name = @Name, 
													@Table = @Table,  
													@JdvAns = @JdvAns,
													@IgnoredValues = @IgnoredValues;

				SET @SqlDoppelganger = N'
					WITH recapDoppelganger AS(
						SELECT 
							J.j_kprocess,
							COUNT(*) AS nbDoublon
						FROM OPENJSON(@JsonCursor, ''$.mapping'') 
						WITH (
							j_kprocess NVARCHAR(MAX) ''$.kprocess'',
							j_code NVARCHAR
							) AS J
						GROUP BY J.j_kprocess)

						INSERT INTO #anomalies(profil, version, fichier_json_name, name, table_name, jeux_de_valeurs_name, 
													j_kprocess,
													doppelganger)
								SELECT
									@Profile,
									@Version,
									@NomDeFichierJson, 
									@Name,
									@Table, 
									@JdvAns,
									j_kprocess,
									CASE WHEN nbDoublon > 1 THEN 1 ELSE 0 END							
								FROM recapDoppelganger AS RDG
								WHERE nbDoublon > 1 AND j_kprocess !='''';
				';


				EXECUTE sp_executesql @SqlDoppelganger, N'@JsonCursor NVARCHAR(MAX),
													@Profile NVARCHAR(MAX), 
													@Version NVARCHAR(MAX),
													@NomDeFichierJson NVARCHAR(MAX), 
													@Name NVARCHAR(500),
													@Table SYSNAME, 
													@JdvAns NVARCHAR(MAX)', 
													@JsonCursor = @JsonCursor, 
													@Profile = @Profile,
													@Version = @Version,
													@NomDeFichierJson = @NomDeFichierJson,
													@Name = @Name, 
													@Table = @Table,  
													@JdvAns = @JdvAns;

				FETCH NEXT FROM foreach INTO @NomDeFichierJson;
			END

		CLOSE foreach;
		DEALLOCATE foreach;
		
		SELECT * FROM #anomalies ORDER BY fichier_json_name;

	END
GO


