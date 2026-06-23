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
		M.ans_jeu_de_valeur_valeur_ref,
		TV.code,
		T.code_system,
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

