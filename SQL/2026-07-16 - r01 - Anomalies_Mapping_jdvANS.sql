USE [OncoPC_DCC_test]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.comparer_mapping_KProcess_ANS
	--@jsonSource = path du fichier jeuxDeValeurs.json
	@jsonSource NVARCHAR(500),
	--@server = par exemple : 'OncoPC_DCC_test'
	@server SYSNAME

	AS
	BEGIN

		SET NOCOUNT ON;

		DECLARE @nomDeFichierJSON AS NVARCHAR (MAX);
		DECLARE @nomDeFichierXML AS NVARCHAR(MAX);
		DECLARE @json AS NVARCHAR (MAX);
		DECLARE @profile AS NVARCHAR (MAX);
		DECLARE @version AS NVARCHAR (MAX);
		DECLARE @name AS NVARCHAR (500);
		DECLARE @ignoredValues AS NVARCHAR(MAX);
		DECLARE @MonSQL AS NVARCHAR (MAX);
		DECLARE @SQLtoMap AS NVARCHAR (MAX);
		DECLARE @SQLtoInsert AS NVARCHAR (MAX);
		DECLARE @SQLextraValues AS NVARCHAR (MAX);
		DECLARE @table AS SYSNAME;
		DECLARE @jdvANS AS NVARCHAR (MAX);
		DECLARE @jsonCursor AS NVARCHAR (MAX);
		DECLARE @pathJSON AS NVARCHAR (MAX);
		DECLARE @pathJSONfile AS NVARCHAR(MAX);
		DECLARE @pathXML AS NVARCHAR(MAX);
		DECLARE @pathXMLfile AS NVARCHAR(MAX);
		DECLARE @MonXml AS NVARCHAR(MAX);

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
			to_insert           BIT DEFAULT 0       
		);

		-- Table temporaire pour stocker le contenu du XML
		DROP TABLE IF EXISTS #valeurs_xml_ans;
		CREATE TABLE #valeurs_xml_ans (
			x_code        NVARCHAR(250),
			x_code_system NVARCHAR(500)
		);

		SET @MonSQL = N'
			SELECT @json = BulkColumn
			FROM OPENROWSET(BULK '''+@jsonSource+''', SINGLE_CLOB) AS source';

		EXECUTE sp_executesql @MonSQL, N'@json NVARCHAR(MAX) OUTPUT', @json = @json OUTPUT;
		
		--Recuperation des valeurs globales du JSON jeuxDeValeurs et du chemin de chaque fichier de mapping
		SELECT @profile = profil,
			   @version = version,
			   @pathJSON = pathJSON,
			   @pathXML = pathJSON
		FROM OPENJSON (@json) WITH (
			profil NVARCHAR (MAX) '$.profile',
			version NVARCHAR (MAX) '$.version',
			pathJSON NVARCHAR (MAX) '$.baseDir'
			);

		SET @pathJSON = @pathJSON + '\kprocess-mapping-ans\Mappings\';
		SET @pathXML = @pathXML + '\kprocess-mapping-ans\JeuxDeValeurs\';
		--Creation de curseur pour naviguer dans chaque fichier json de mapping
		DECLARE foreach CURSOR LOCAL FAST_FORWARD
			FOR SELECT fichier
				FROM OPENJSON (@json, '$.mappings') WITH (fichier NVARCHAR (MAX) '$.file');

		OPEN foreach;

		FETCH NEXT FROM foreach INTO @nomDeFichierJSON;

		WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @pathJSONfile = @pathJSON + @nomDeFichierJSON;
				--Lecture du fichier JSON specifique à chaque jeu de valeur
				SET @MonSQL = N'SELECT @jsonCursor = BulkColumn
							FROM OPENROWSET(BULK ''' + @pathJSONfile + ''', SINGLE_CLOB) AS sourceJSON';
				EXECUTE sp_executesql @MonSQL, N'@jsonCursor NVARCHAR(MAX) OUTPUT', @jsonCursor = @jsonCursor OUTPUT;

				--Lecture du fichier XML du jeu de valeur associé au JSON
				SELECT @nomDeFichierXML = fichierXML
				FROM   OPENJSON (@jsonCursor) WITH (fichierXML NVARCHAR (MAX) '$.jeuDeValeursANS');

				SET @pathXMLfile = @pathXML + @nomDeFichierXML + '.xml';
				
				TRUNCATE TABLE #valeurs_xml_ans;

				--Recuperation des données du jeu de valeur XML dans une tablea temporaire #valeurs_xml_ans
				SET @MonXml = N'
					DECLARE @xml XML;
					SELECT @xml = CAST(BulkColumn AS XML)
					FROM OPENROWSET(BULK '''+@pathXMLfile+''', SINGLE_BLOB) AS sourceXML;
					WITH XMLNAMESPACES (''urn:ihe:iti:svs:2008'' AS ns)
					INSERT INTO #valeurs_xml_ans (x_code, x_code_system)
					SELECT
						concept.value(''@code'',        ''NVARCHAR(250)'')    AS x_code,
						concept.value(''@codeSystem'', ''NVARCHAR(500)'')  AS x_code_system
					FROM @xml.nodes(''/ns:RetrieveValueSetResponse/ns:ValueSet/ns:ConceptList/ns:Concept'') AS ANS(concept);';
					EXECUTE sp_executesql @MonXMl;


				--Assignation des valeurs specifiques du JSON aux variables @table, @jdvANS, @name et @ignoredValues
				SELECT @table = tableName, @jdvANS = jeuDeValeursANS, @name = name, @ignoredValues = ignoredValues
				FROM OPENJSON (@jsonCursor) WITH (
					tableName NVARCHAR (MAX) '$.tableName',
					jeuDeValeursANS NVARCHAR (MAX) '$.jeuDeValeursANS',
					name NVARCHAR (500) '$.name',
					ignoredValues NVARCHAR(MAX) '$.ignoresValues' AS JSON);

				SET @SQLextraValues = N'
					WITH recapExtraValues AS(
						SELECT 
							J.j_kprocess, 
							J.j_code, 
							J.j_code_system,
							COALESCE(J.is_ignored, 0) AS is_ignored,
							K.value AS k_values, 
							K.code AS k_code
						FROM OPENJSON(@jsonCursor, ''$.mapping'') 
							WITH (
								j_kprocess NVARCHAR(MAX) ''$.kprocess'', 
								j_code NVARCHAR(MAX) ''$.code'',
								j_code_system NVARCHAR(500) ''$.codeSystem'',
								is_ignored BIT ''$.ignore''
							) AS J
						FULL JOIN ' + @server + '.' + @table + ' AS K ON K.value = J.j_kprocess)
						INSERT INTO #anomalies (profil, version, fichier_json_name, name, table_name, jeux_de_valeurs_name,
												j_kprocess, j_code, j_code_system,
												k_values, k_code, is_ignored, extra_value)
							SELECT
								@profile,
								@version,
								@nomDeFichierJSON, 
								@name,
								@table, 
								@jdvANS,
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
									END
							FROM recapExtraValues AS REV
							WHERE k_values IS NOT NULL 
								AND (j_code IS NULL OR j_kprocess IS NULL)
								AND is_ignored = 0; 
							';
				EXECUTE sp_executesql @SQLextraValues, N'@jsonCursor NVARCHAR(MAX),
														@profile NVARCHAR(MAX), 
														@version NVARCHAR(MAX),
														@nomDeFichierJSON NVARCHAR(MAX), 
														@name NVARCHAR(500),
														@table SYSNAME, 
														@jdvANS NVARCHAR(MAX)', 
														@jsonCursor = @jsonCursor, 
														@profile = @profile,
														@version = @version,
														@nomDeFichierJSON = @nomDeFichierJSON,
														@name = @name, 
														@table = @table,  
														@jdvANS = @jdvANS;

				SET @SQLtoInsert = N'
							WITH recapToInsert AS(
								SELECT 
									J.j_kprocess, 
									J.j_code, 
									J.j_code_system,
									COALESCE(J.is_ignored, 0) AS is_ignored,
									J.j_additional_values,
									K.value AS k_values, 
									K.code AS k_code
								FROM OPENJSON(@jsonCursor, ''$.mapping'') 
								WITH (
									j_kprocess NVARCHAR(MAX) ''$.kprocess'', 
									j_code NVARCHAR(MAX) ''$.code'',
									j_code_system NVARCHAR(500) ''$.codeSystem'',
									is_ignored BIT ''$.ignore'',
									j_additional_values NVARCHAR(MAX) ''$.additionalValues'' AS JSON
									) AS J
						
								FULL JOIN ' + @server + '.' + @table + ' AS K ON K.value = J.j_kprocess
							)
							INSERT INTO #anomalies(profil, version, fichier_json_name, name, table_name, jeux_de_valeurs_name, 
													j_kprocess, j_code, j_code_system,
													k_values, k_code, 
													is_ignored, to_insert)
								SELECT
									@profile,
									@version,
									@nomDeFichierJSON, 
									@name,
									@table, 
									@jdvANS,
									j_kprocess,
									j_code, 
									j_code_system,
									k_values,
									k_code,
									is_ignored,
									CASE WHEN (k_values IS NULL OR k_values ='''') 
											AND COALESCE(is_ignored, 0) = 0 
											AND (j_kprocess IS NOT NULL OR j_code IS NOT NULL)
												THEN 1 ELSE 0 END
								FROM recapToInsert AS RTI
								WHERE k_values IS NULL OR k_values = '''';
							';
				EXECUTE sp_executesql @SQLtoInsert, N'@jsonCursor NVARCHAR(MAX),
													@profile NVARCHAR(MAX), 
													@version NVARCHAR(MAX),
													@nomDeFichierJSON NVARCHAR(MAX), 
													@name NVARCHAR(500),
													@table SYSNAME, 
													@jdvANS NVARCHAR(MAX)', 
													@jsonCursor = @jsonCursor, 
													@profile = @profile,
													@version = @version,
													@nomDeFichierJSON = @nomDeFichierJSON,
													@name = @name, 
													@table = @table,  
													@jdvANS = @jdvANS;

				SET @SQLtoMap = N'
					WITH recapIgnoresValues AS (
						SELECT 
							i_code, 
							i_code_system
						FROM OPENJSON(@ignoredValues)
						WITH (
							i_code NVARCHAR(MAX) ''$.code'',
							i_code_system NVARCHAR(500) ''$.codeSystem''
						)
					),
					recapAdditionalValues AS (
						SELECT 
							ADV.adv_code,
							ADV.adv_code_system
						FROM OPENJSON(@jsonCursor, ''$.mapping'') 
						WITH (
							j_additional_values NVARCHAR(MAX) ''$.additionalValues'' AS JSON
						) AS J
						CROSS APPLY OPENJSON(J.j_additional_values)
						WITH (
							adv_code NVARCHAR(MAX) ''$.code'',
							adv_code_system NVARCHAR(500) ''$.codeSystem''
						) AS ADV
						WHERE J.j_additional_values IS NOT NULL
					),
					recapComparatif AS(
						SELECT 
							J.j_kprocess, 
							J.j_code, 
							J.j_code_system,
							J.j_additional_values,
							X.x_code,
							X.x_code_system,
							I.i_code,
							ADV.adv_code
						FROM OPENJSON(@jsonCursor, ''$.mapping'') 
						WITH (
							j_kprocess NVARCHAR(MAX) ''$.kprocess'', 
							j_code NVARCHAR(MAX) ''$.code'',
							j_code_system NVARCHAR(500) ''$.codeSystem'',
							j_additional_values NVARCHAR(MAX) ''$.additionalValues'' AS JSON
						) AS J
							FULL JOIN #valeurs_xml_ans AS X ON J.j_code = X.x_code AND J.j_code_system = X.x_code_system
							FULL JOIN recapIgnoresValues AS I ON X.x_code = I.i_code
							LEFT JOIN recapAdditionalValues AS ADV ON X.x_code = ADV.adv_code AND X.x_code_system = ADV.adv_code_system
					)
					INSERT INTO #anomalies(profil, version, fichier_json_name, name, table_name, jeux_de_valeurs_name, 
											j_kprocess, j_code, j_code_system, j_ignored_values, j_additional_values,
											x_code, x_code_system,
											value_to_map)
						SELECT
							@profile,
							@version,
							@nomDeFichierJSON, 
							@name,
							@table, 
							@jdvANS,
							j_kprocess,
							j_code, 
							j_code_system,							
							i_code,
							adv_code,
							x_code,
							x_code_system,
							CASE WHEN (j_kprocess IS NULL OR j_kprocess ='''') 
								AND x_code IS NOT NULL					
								AND i_code IS NULL
								AND x_code NOT IN (
										SELECT adv_code
										FROM recapComparatif
										WHERE adv_code IS NOT NULL)
									THEN 1 ELSE 0 END
						FROM recapComparatif AS RC
						WHERE 
							(j_kprocess IS NULL OR j_code='''') 
							AND x_code IS NOT NULL;';
				EXECUTE sp_executesql @SQLtoMap, N'@jsonCursor NVARCHAR(MAX),
													@profile NVARCHAR(MAX), 
													@version NVARCHAR(MAX),
													@nomDeFichierJSON NVARCHAR(MAX), 
													@name NVARCHAR(500),
													@table SYSNAME, 
													@jdvANS NVARCHAR(MAX), 
													@ignoredValues NVARCHAR(MAX)',
													@jsonCursor = @jsonCursor, 
													@profile = @profile,
													@version = @version,
													@nomDeFichierJSON = @nomDeFichierJSON,
													@name = @name, 
													@table = @table,  
													@jdvANS = @jdvANS,
													@ignoredValues = @ignoredValues;

				FETCH NEXT FROM foreach INTO @nomDeFichierJSON;
			END

		CLOSE foreach;
		DEALLOCATE foreach;
		
		SELECT * FROM #anomalies ORDER BY fichier_json_name;

	END
GO