ALTER TABLE core.sexe_enum
ADD code AS (value);

ALTER TABLE dbo.etablissements_practice_settings_enum
ADD code AS (value);

ALTER TABLE account.profil_professionnel_sante_titre_enum
ADD code AS (value);

ALTER TABLE dbo.fiches_rcp_v1_capacite_oms_enum
ADD value AS (code);

ALTER TABLE dbo.etablissements_type_enum
ADD value AS (code);

ALTER TABLE dbo.tumeur_enum
ADD value AS (code);