
IF EXISTS
		  (
		   SELECT 1
		   FROM sysobjects
		   WHERE name = 'Capit_V_COLUMNS_DEFAULTS'
				 AND xtype = 'V'
		  ) 
BEGIN
	DROP VIEW Capit_V_COLUMNS_DEFAULTS
END;
GO
/*
Description
***********
La vue "Capit_COLUMNS_DEFAULTS" est basée sur les vues système SQL Server. Elle permet de ramener facilement les valeurs par défaut des colonnes d'une base SQL Server.

Evolutions
**********
Pour faire évoluer cette vue, écrivez à info@capit.net

*/
CREATE VIEW Capit_V_COLUMNS_DEFAULTS
AS SELECT so.name AS   constraint_name
		, st.name AS   table_name
		, sc.name AS   column_name
		, typ.name AS  column_type
		, sc.length AS column_length
		, sm.text AS   constraint_text
   FROM sysobjects AS so
	   INNER JOIN sysconstraints AS sd
		   ON so.id = sd.constid
	   INNER JOIN sysobjects AS st
		   ON st.id = sd.id
	   INNER JOIN syscolumns AS sc
		   ON sc.id = st.id
			  AND sc.colid = sd.colid
	   INNER JOIN syscomments AS sm
		   ON sm.id = sd.constid
	   INNER JOIN systypes AS typ
		   ON typ.xtype = sc.xtype
   WHERE so.xtype = 'D';
GO

IF EXISTS
		  (
		   SELECT *
		   FROM sysobjects
		   WHERE name = 'Capit_sp_ConvertFormat'
				 AND xtype = 'P'
		  ) 
BEGIN
	DROP PROCEDURE Capit_sp_ConvertFormat
END;

GO
/*
Description
***********
Capit_sp_ConvertFormat  permet de convertir une colonne d'un type vers un autre
 
Paramètres
**********
La procédure prend 4 paramètres
@tableName : Nom de la table où se trouve la colonne à transformer
@columnName : Nom de la colonne à transformer
@FormatTo : Format destinatation
@bRaiseError (optionnel) : Flag indiquant si une erreur doit être soulevée en cas de problème

Dépendances
***********
Cette procédure utilise :
Capit_V_COLUMNS_DEFAULTS

Restrictions
************
Seules les contraintes de type "default" sont actuellement gérées
Les scripts ne fonctionnent que pour les bases en Case-Insensitive
Pour faire évoluer cette procédure, écrivez à info@capit.net

Exemple
*******
exec Capit_sp_ConvertFormat 'textes', 'd_creation', 'smalldatetime'

*/
CREATE PROCEDURE Capit_sp_ConvertFormat 
				 @TableName   SYSNAME
			   , @columnName  SYSNAME
			   , @FormatTo    SYSNAME
			   , @bRaiseError BIT     = 0
AS
BEGIN
	DECLARE @sSqlDropDefaultConstraint VARCHAR(8000);
	DECLARE @sSqlAddDefaultConstraint VARCHAR(8000);
	DECLARE @sSql VARCHAR(8000);
	DECLARE @constraint_name SYSNAME;
	DECLARE @column_default NVARCHAR(4000);
	DECLARE @sErrorMessage VARCHAR(8000);
	DECLARE @dataType SYSNAME;
	DECLARE @severity TINYINT;
	DECLARE @state TINYINT;

	-- Initialisation

	SET @dataType = '';
	SET @column_default = '';
	SET @sSqlDropDefaultConstraint = '';
	SET @sSqlAddDefaultConstraint = '';
	SET @sSql = '';

	-- Vérification de l'existence de la colonne et de son type

	SELECT @column_default = ISNULL(COLUMN_DEFAULT, '')
		 , @dataType = DATA_TYPE
	FROM information_schema.columns
	WHERE table_name = @TableName
		  AND column_name = @ColumnName;

	-- La colonne n'existe pas
	IF @dataType = ''
	BEGIN
		SET @sErrorMessage = 'La colonne ' + @ColumnName + ' n''existe pas  dans la table ' + @TableName;
		IF @bRaiseError = 1
		BEGIN
			RAISERROR(@sErrorMessage, 1, 1);
		END
			ELSE
		BEGIN
			PRINT @sErrorMessage;
		END;
	END;
		ELSE
	BEGIN	
		-- La colonne existe mais a déjà le type cible
		IF @dataType = @FormatTo
		BEGIN
			PRINT 'La colonne ' + @ColumnName + ' de la table ' + @TableName + ' est déjà de type ' + @dataType;
		END;
			ELSE
		BEGIN
			-- dans le cas ou une contrainte par défaut est présente sur la colonne, il faut la supprimer	
			IF @column_default != ''
			BEGIN
				SELECT @constraint_name = constraint_name
				FROM Capit_V_COLUMNS_DEFAULTS
				WHERE table_name = @tablename
					  AND column_name = @columnName;
			
				-- Construction de l'ordre pour supprimer la contrainte par defaut
				SET @sSqlDropDefaultConstraint = 'ALTER TABLE ' + @tablename + ' drop CONSTRAINT ' + @constraint_name;
			
				-- Construction de l'ordre pour remettre la contrainte par défaut
				SET @sSqlAddDefaultConstraint = 'ALTER TABLE ' + @tablename + ' ADD CONSTRAINT ' + @constraint_name + ' DEFAULT ' + @column_default + ' FOR ' + @columnName;
			END;


			IF @sSqlDropDefaultConstraint != ''
			BEGIN
				-- execution de la requête droppant la contrainte par défaut
				PRINT @sSqlDropDefaultConstraint;
				EXEC (@sSqlDropDefaultConstraint);
			END;

			SET @sErrorMessage = '';

			-- requête transformant le type de la colonne ( par exemple de DateTime en SmallDateTime )
			SET @sSql = 'Alter table ' + @tablename + ' alter column ' + @columnName + ' ' + @FormatTo;
			PRINT @sSql;
			BEGIN TRY
				EXEC (@sSql);
			END TRY
			BEGIN CATCH
				SET @sErrorMessage = 'Il n''a pas été possible de convertir la ' + @ColumnName + ' de la table ' + @TableName + ' du type ' + @dataType + ' vers ' + @formatTo;
				SET @sErrorMessage = @sErrorMessage + ' Error ' + CONVERT(VARCHAR, ERROR_NUMBER()) + ' Severity ' + CONVERT(VARCHAR, ERROR_SEVERITY()) + ' State ' + CONVERT(VARCHAR, ERROR_STATE()) + ' Procedure ' + CONVERT(VARCHAR, ERROR_PROCEDURE()) + ' Line ' + CONVERT(VARCHAR, ERROR_LINE()) + ' Message ' + CONVERT(VARCHAR, ERROR_MESSAGE());
				SET @severity = ERROR_SEVERITY();
				SET @state = ERROR_STATE();
			END CATCH;

			IF @sSqlAddDefaultConstraint != ''
			BEGIN
				-- execution de la requête remettant la contrainte par défaut
				PRINT @sSqlAddDefaultConstraint;
				EXEC (@sSqlAddDefaultConstraint);
			END; 

			-- Dans le cas ou il y a eu une erreur lors de la transformation, on soulève une erreur
			IF @sErrorMessage != ''
			BEGIN
				IF @bRaiseError = 1
				BEGIN
					RAISERROR(@sErrorMessage, @severity, @state);
				END
					ELSE
				BEGIN
					PRINT @sErrorMessage;
				END;
			END;
		END;
	END;
END;
GO

IF EXISTS
		  (
		   SELECT *
		   FROM sysobjects
		   WHERE name = 'Capit_sp_DateTimeToSmallDateTime'
				 AND xtype = 'P'
		  ) 
BEGIN
	DROP PROCEDURE Capit_sp_DateTimeToSmallDateTime
END;
GO
/*
Description
***********
Capit_sp_DateTimeToSmallDateTime  permet de tranformer une colonne de type DateTime en une colonne de Type smalldatetime
Une colonne de type DateTime prend 8 Octets alors qu'un smalldatetime prend 4 octets. On economise donc 4 octets par ligne.
Les colonnes de types datetime peuvent contenir des valeurs du 1er janvier 1753 au 31 décembre 9999 avec une précision de 3,33 millisecondes
Les colonnes de types smalldatetime peuvent contenir des valeurs du 1er janvier 1900 au 6 juin 2079 avec une précision à la minute
 
Paramètres
**********
La procédure prend 3 paramètres
@tableName : Nom de la table où se trouve la colonne à transformer
@columnName : Nom de la colonne à transformer
@bRaiseError (optionnel) : Flag indiquant si une erreur doit être soulevé lorsque la colonne n'existe pas

Dépendances
***********
Cette procédure utilise :
Capit_sp_ConvertFormat
Capit_V_COLUMNS_DEFAULTS

Restrictions
************
Seules les contraintes de type "default" sont actuellement gérées
Les scripts ne fonctionnent que pour les bases en Case-Insensitive
Pour faire évoluer cette procédure, écrivez à info@capit.net

Exemple
*******
exec Capit_sp_DateTimeToSmallDateTime 'textes', 'd_creation'

*/
CREATE PROCEDURE Capit_sp_DateTimeToSmallDateTime 
				 @TableName   SYSNAME
			   , @columnName  SYSNAME
			   , @bRaiseError BIT     = 0
AS
BEGIN
	DECLARE @sErrorMessage VARCHAR(8000);
	IF NOT EXISTS
				  (
				   SELECT 1
				   FROM information_schema.columns
				   WHERE table_name = @TableName
						 AND column_name = @ColumnName
						 AND data_type = 'datetime'
				  ) 
	BEGIN
		SET @sErrorMessage = 'La colonne ' + @ColumnName + ' n''existe pas  dans la table ' + @TableName + ' ou elle n''est pas de type DateTime ';
		IF @bRaiseError = 1
		BEGIN
			RAISERROR(@sErrorMessage, 1, 1);
		END;
			ELSE
		BEGIN
			PRINT @sErrorMessage;
		END;
	END;
		ELSE
	BEGIN
		EXEC Capit_sp_ConvertFormat @TableName
								  , @columnName
								  , 'smalldatetime'
								  , @bRaiseError;
	END;
END;
GO
IF EXISTS
		  (
		   SELECT *
		   FROM sysobjects
		   WHERE name = 'capit_sp_ConvertAllColumns'
				 AND xtype = 'P'
		  ) 
BEGIN
	DROP PROCEDURE capit_sp_ConvertAllColumns
END;
GO
/*
Description
***********
capit_sp_ConvertAllColumns  permet de tranformer toutes les colonnes d'un type particulier.
Celà peut être utile lorsque l'on veut transformer toutes les colonnes de type DateTime en smalldatetime.
 
Paramètres
**********
La procédure prend 2 paramètres
@FormatFrom : de le type de colonnes à transformer
@FormatTo : le type de colonnes cibles

Dépendances
***********
Cette procédure utilise :
Capit_sp_ConvertFormat
Capit_V_COLUMNS_DEFAULTS

Restrictions
************
Seules les contraintes de type "default" sont actuellement gérées
Les scripts ne fonctionnent que pour les bases en Case-Insensitive
Pour faire évoluer cette procédure, écrivez à info@capit.net

Exemples
********
exec capit_sp_ConvertAllColumns 'DateTime','smalldatetime'

*/
CREATE PROCEDURE capit_sp_ConvertAllColumns 
				 @FormatFrom SYSNAME
			   , @FormatTo   SYSNAME
AS
BEGIN
	DECLARE @columnname SYSNAME;
	DECLARE @tablename SYSNAME;

	-- cursor listant toutes les colonnes du type recherché
	DECLARE cCol CURSOR
	FOR SELECT col.table_name
			 , col.column_name
		FROM information_schema.columns AS col
			INNER JOIN information_schema.tables AS tab
				ON col.table_name = tab.table_name
		WHERE col.data_type = @FormatFrom
			  AND tab.table_type = 'BASE TABLE';
	OPEN cCol;
	FETCH NEXT FROM cCol INTO @tablename
							, @columnName;

	WHILE @@fetch_status = 0
	BEGIN
		PRINT 'Convert ' + @tablename + '.' + @columnName + ' from ' + @FormatFrom + ' to ' + @FormatTo;
		-- conversion au format cible
		EXEC Capit_sp_ConvertFormat @tablename
								  , @columnName
								  , @formatTo;
		FETCH NEXT FROM cCol INTO @tablename
								, @columnName;
	END;
	CLOSE cCol;
	DEALLOCATE cCol;
END;
GO
IF EXISTS
		  (
		   SELECT *
		   FROM sysobjects
		   WHERE name = 'Capit_sp_DropColumn'
				 AND xtype = 'P'
		  ) 
BEGIN
	DROP PROCEDURE Capit_sp_DropColumn
END;
GO

/*
Description
***********
Capit_sp_DropColumn  permet de supprimer une colonne d'une table
 
Paramètres
**********
La procédure prend 3 paramètres
@tableName : Nom de la table où se trouve la colonne à transformer
@columnName : Nom de la colonne à transformer
@bRaiseError (optionnel) : Flag indiquant si une erreur doit être soulevée en cas de problème

Dépendances
***********
Cette procédure utilise :
Capit_V_COLUMNS_DEFAULTS

Restrictions
************
Seules les contraintes de type "default" sont actuellement gérées
Les scripts ne fonctionnent que pour les bases en Case-Insensitive
Pour faire évoluer cette procédure, écrivez à info@capit.net

Exemple
*******
exec Capit_sp_DropColumn 'textes', 'n_note'

*/
CREATE PROCEDURE Capit_sp_DropColumn 
				 @TableName   SYSNAME
			   , @columnName  SYSNAME
			   , @bRaiseError BIT     = 0
AS
BEGIN
	DECLARE @sSqlDropDefaultConstraint VARCHAR(8000);
	DECLARE @sSql VARCHAR(8000);
	DECLARE @constraint_name SYSNAME;
	DECLARE @column_default NVARCHAR(4000);
	DECLARE @sErrorMessage VARCHAR(8000);
	DECLARE @dataType SYSNAME;
	DECLARE @severity TINYINT;
	DECLARE @state TINYINT;

	-- Initialisation

	SET @dataType = '';
	SET @column_default = '';
	SET @sSqlDropDefaultConstraint = '';
	SET @sSql = '';

	-- Vérification de l'existence de la colonne et de son type

	SELECT @column_default = ISNULL(COLUMN_DEFAULT, '')
		 , @dataType = DATA_TYPE
	FROM information_schema.columns
	WHERE table_name = @TableName
		  AND column_name = @ColumnName;

	-- La colonne n'existe pas
	IF @dataType = ''
	BEGIN
		SET @sErrorMessage = 'La colonne ' + @ColumnName + ' n''existe pas  dans la table ' + @TableName;
		IF @bRaiseError = 1
		BEGIN
			RAISERROR(@sErrorMessage, 1, 1);
		END
			ELSE
		BEGIN
			PRINT @sErrorMessage;
		END;
	END;
		ELSE
	BEGIN	
		-- dans le cas ou une contrainte par défaut est présente sur la colonne, il faut la supprimer	
		IF @column_default != ''
		BEGIN
			SELECT @constraint_name = constraint_name
			FROM Capit_V_COLUMNS_DEFAULTS
			WHERE table_name = @tablename
				  AND column_name = @columnName;
			
			-- Construction de l'ordre pour supprimer la contrainte par defaut
			SET @sSqlDropDefaultConstraint = 'ALTER TABLE ' + @tablename + ' drop CONSTRAINT ' + @constraint_name;
		END;

		SET @sErrorMessage = '';
		BEGIN TRY

			IF @sSqlDropDefaultConstraint != ''
			BEGIN
				-- execution de la requête supprimant la contrainte par défaut
				PRINT @sSqlDropDefaultConstraint;
				EXEC (@sSqlDropDefaultConstraint);
			END;

			-- requête supprimant la colonne 
			SET @sSql = 'Alter table ' + @tablename + ' drop column ' + @columnName;
			PRINT @sSql;
			EXEC (@sSql);
		END TRY
		BEGIN CATCH
			SET @sErrorMessage = 'Il n''a pas été possible de supprimer la colonne ' + @ColumnName + ' de la table ' + @TableName + ' de type ' + @dataType;
			SET @sErrorMessage = @sErrorMessage + ' Error ' + CONVERT(VARCHAR, ERROR_NUMBER()) + ' Severity ' + CONVERT(VARCHAR, ERROR_SEVERITY()) + ' State ' + CONVERT(VARCHAR, ERROR_STATE()) + ' Procedure ' + CONVERT(VARCHAR, ERROR_PROCEDURE()) + ' Line ' + CONVERT(VARCHAR, ERROR_LINE()) + ' Message ' + CONVERT(VARCHAR, ERROR_MESSAGE());
			SET @severity = ERROR_SEVERITY();
			SET @state = ERROR_STATE();
			IF @bRaiseError = 1
			BEGIN
				RAISERROR(@sErrorMessage, @severity, @state);
			END
				ELSE
			BEGIN
				PRINT @sErrorMessage;
			END;
		END CATCH;

	END;
END;
GO


