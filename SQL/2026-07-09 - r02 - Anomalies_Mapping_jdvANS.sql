USE [OncoPC_DCC_test]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.comparer_mapping_KProcess_ANS
AS
BEGIN
    SET NOCOUNT ON;
   DECLARE @MonNomDeFichier AS NVARCHAR(MAX);
DECLARE @json NVARCHAR(MAX);
DECLARE @profile NVARCHAR(MAX);
DECLARE @version NVARCHAR(MAX);
DECLARE @name NVARCHAR(500);
DECLARE @MonSQL AS NVARCHAR(MAX);
DECLARE @table AS SYSNAME;
DECLARE @jdvANS AS NVARCHAR(MAX);
DECLARE @jsonCursor NVARCHAR(MAX);
DECLARE @path NVARCHAR(MAX);
DECLARE @server AS SYSNAME;
SET @server = 'OncoPC_DCC_test';

DROP TABLE IF EXISTS #anomalies;

CREATE TABLE #anomalies( 
		profil				NVARCHAR(MAX),
		version				NVARCHAR(250),
		nom_fichier_json	NVARCHAR(MAX),
		name				NVARCHAR(500),
        table_name			SYSNAME,
		jeux_de_valeurs_ANS NVARCHAR(MAX),
        values_KP			NVARCHAR(MAX),
		code_KP				NVARCHAR(MAX),
        code_ANS			NVARCHAR(MAX),
		code_system_ANS		NVARCHAR(MAX),
        is_ignored				BIT);

SELECT @json = BulkColumn
FROM OPENROWSET(BULK 'C:\Users\Public\Documents\kprocess-mapping-ans\jeuxDeValeurs.json', SINGLE_CLOB) AS source;

SELECT @profile = profil
			FROM OPENJSON(@json)
			WITH (
				profil NVARCHAR(MAX) '$.profile');

SELECT @version = version
			FROM OPENJSON(@json)
			WITH (
				version NVARCHAR(MAX) '$.version');

DECLARE foreach CURSOR LOCAL FAST_FORWARD
	FOR SELECT fichier 
	FROM OPENJSON(@json, '$.mappings')
	WITH (fichier NVARCHAR(MAX) '$.file');

-- ITERATION SUR CHAQUE ITEM listé dans mapping de jeuxDeValeurs.json
OPEN foreach
FETCH NEXT FROM foreach INTO @MonNomDeFichier;
WHILE @@FETCH_STATUS = 0  
   BEGIN  
   --PRINT @MonNomDeFichier;
		SET @path = 'C:\Users\Public\Documents\kprocess-mapping-ans\Mappings\' + @MonNomDeFichier;
		SET @MonSQL = N'SELECT @jsonCursor = BulkColumn
			FROM OPENROWSET(BULK '''+@path+''', SINGLE_CLOB) AS source';

		EXEC sp_executesql @MonSQL,N'@jsonCursor NVARCHAR(MAX) OUTPUT', @jsonCursor = @jsonCursor OUTPUT;
		
		--Recuperation des valeurs de la table KProcess specifiée dans le JSON
		SELECT @table = tableName
			FROM OPENJSON(@jsonCursor)
			WITH (
				tableName NVARCHAR(MAX) '$.tableName');

		SELECT @jdvANS = jeuDeValeursANS
			FROM OPENJSON(@jsonCursor)
			WITH (
				jeuDeValeursANS NVARCHAR(MAX) '$.jeuDeValeursANS');

		SELECT @name = name
			FROM OPENJSON(@jsonCursor)
			WITH (
				name NVARCHAR(500) '$.name');

		SET @MonSQL = N'
			WITH recapComparatif AS(
				SELECT 
					J.kprocess, 
					J.codeANS, 
					J.code_system,
					J.is_ignored,
					T.value AS value_KP, 
					T.code AS code_KP
				FROM OPENJSON(@jsonCursor, ''$.mapping'') 
				WITH (
					kprocess NVARCHAR(MAX) ''$.kprocess'', 
					codeANS NVARCHAR(MAX) ''$.code'',
					code_system NVARCHAR(500) ''$.codeSystem'',
					is_ignored BIT ''$.ignore''
				) AS J
				FULL JOIN '+ @server +'.'+ @table + ' AS T ON T.value = J.kprocess
			)
			INSERT INTO #anomalies(profil, version, nom_fichier_json, name, table_name, jeux_de_valeurs_ANS, values_KP, code_KP, code_ANS, code_system_ANS, is_ignored)
				SELECT 
					@profile,
					@version,
					@MonNomDeFichier, 
					@name,
					@table, 
					@jdvANS,
					value_KP,
					code_KP,
					codeANS, 
					code_system,
					is_ignored
				FROM recapComparatif 
				WHERE codeANS IS NULL OR value_KP IS NULL OR value_KP = '''' OR codeANS='''';';
		EXEC sp_executesql @MonSQL, N'@jsonCursor NVARCHAR(MAX), @MonNomDeFichier NVARCHAR(MAX), @name NVARCHAR(500), @table SYSNAME, @jdvANS NVARCHAR(MAX), @profile NVARCHAR(MAX), @version NVARCHAR(MAX)',
		@jsonCursor = @jsonCursor,
		@table = @table,
		@MonNomDeFichier = @MonNomDeFichier,
		@name = @name,
		@jdvANS = @jdvANS,
		@version = @version,
		@profile=@profile;
	
		FETCH NEXT FROM foreach INTO @MonNomDeFichier;
   END;
CLOSE foreach;  
DEALLOCATE foreach;

SELECT * FROM #anomalies;

END
GO