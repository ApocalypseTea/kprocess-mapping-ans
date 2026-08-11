--ALTER TABLE ans.ZT_mapping ADD kprocess_id INT ;
--ALTER TABLE ans.ZT_mapping ADD kprocess_label VARCHAR(250);

GO


ALTER   PROCEDURE [ans].[ZSP_update_mapping_mapping](@Profil VARCHAR(250), @Version VARCHAR(250), @JSON VARCHAR(MAX))
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
	WHEN NOT MATCHED BY SOURCE THEN DELETE;
END

GO


ALTER   VIEW [ans].[mapping]
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

