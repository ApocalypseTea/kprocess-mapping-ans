
CREATE OR ALTER PROCEDURE ans.ZSP_update_mapping_mapping(@Profil VARCHAR(250), @Version VARCHAR(250), @JSON VARCHAR(MAX))
AS BEGIN 
	DECLARE @TableMapping TABLE(kprocess_value VARCHAR(50), for_import BIT, ans_jeu_de_valeur_valeur_ref BIGINT, code VARCHAR(250), code_system VARCHAR(250));
	DECLARE @ProfilVersionID BIGINT;
	DECLARE @KProcessJeuValeurID BIGINT;

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