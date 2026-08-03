
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


