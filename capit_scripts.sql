if exists ( select 1 from sysobjects where name='Capit_V_COLUMNS_DEFAULTS' and xtype = 'V')
drop view Capit_V_COLUMNS_DEFAULTS
go
/*
Description
***********
La vue "Capit_COLUMNS_DEFAULTS" est bas�e sur les vues syst�me SQL Server. Elle permet de ramener facilement les valeurs par d�faut des colonnes d'une base SQL Server.

Evolutions
**********
Pour faire �voluer cette vue, �crivez � info@capit.net

*/
create View Capit_V_COLUMNS_DEFAULTS as 
select  
	so.name as constraint_name, 
	st.name as table_name, 
	sc.name as column_name, 
	typ.name as column_type,
	sc.length as column_length,
	sm.text AS constraint_text
from sysobjects so
	inner join sysconstraints sd on so.id = sd.constid
	inner join sysobjects st on st.id = sd.id
	inner join syscolumns sc on sc.id = st.id and sc.colid = sd.colid
	inner join syscomments sm on sm.id = sd.constid
	inner join systypes typ on typ.xtype = sc.xtype
where so.xtype = 'D'
go

if exists ( select * from sysobjects where name='Capit_sp_ConvertFormat' and xtype = 'P')
drop procedure Capit_sp_ConvertFormat

go
/*
Description
***********
Capit_sp_ConvertFormat  permet de convertir une colonne d'un type vers un autre
 
Param�tres
**********
La proc�dure prend 4 param�tres
@tableName : Nom de la table o� se trouve la colonne � transformer
@columnName : Nom de la colonne � transformer
@FormatTo : Format destinatation
@bRaiseError (optionnel) : Flag indiquant si une erreur doit �tre soulev�e en cas de probl�me

D�pendances
***********
Cette proc�dure utilise :
Capit_V_COLUMNS_DEFAULTS

Restrictions
************
Seules les contraintes de type "default" sont actuellement g�r�es
Les scripts ne fonctionnent que pour les bases en Case-Insensitive
Pour faire �voluer cette proc�dure, �crivez � info@capit.net

Exemple
*******
exec Capit_sp_ConvertFormat 'textes', 'd_creation', 'smalldatetime'

*/
create procedure Capit_sp_ConvertFormat
@TableName sysname,
@columnName sysname,
@FormatTo sysname,
@bRaiseError bit = 0
as
declare @sSqlDropDefaultConstraint varchar(8000)
declare @sSqlAddDefaultConstraint varchar(8000)
declare @sSql varchar(8000)
declare @constraint_name sysname
Declare @column_default nvarchar(4000)
Declare @sErrorMessage varchar(8000)
declare @dataType sysname
declare @severity tinyint
declare @state tinyint

-- Initialisation

set @dataType = ''
set @column_default= ''
set @sSqlDropDefaultConstraint = ''
set @sSqlAddDefaultConstraint = ''
set @sSql = ''

-- V�rification de l'existence de la colonne et de son type

select @column_default = isnull(COLUMN_DEFAULT,''), @dataType = DATA_TYPE
			from information_schema.columns 
			where table_name = @TableName
			and column_name = @ColumnName

-- La colonne n'existe pas
if @dataType = ''
begin
	set @sErrorMessage = 'La colonne ' + @ColumnName + ' n''existe pas  dans la table '+@TableName
	if @bRaiseError=1
		RAISERROR ( @sErrorMessage, 1, 1)
	else
		print 	@sErrorMessage
end
else
begin	
	-- La colonne existe mais a d�j� le type cible
	if @dataType = @FormatTo
	begin
		print 'La colonne ' + @ColumnName + ' de la table '+@TableName + ' est d�j� de type ' + @dataType
	end
	else
	begin
		-- dans le cas ou une contrainte par d�faut est pr�sente sur la colonne, il faut la supprimer	
		if @column_default != ''
		begin
		   select @constraint_name = constraint_name
			from Capit_V_COLUMNS_DEFAULTS 
			where table_name = @tablename 
			and column_name = @columnName
			
			-- Construction de l'ordre pour supprimer la contrainte par defaut
			set @sSqlDropDefaultConstraint = 'ALTER TABLE '+@tablename + ' drop CONSTRAINT ' + @constraint_name
			
			-- Construction de l'ordre pour remettre la contrainte par d�faut
			set @sSqlAddDefaultConstraint = 'ALTER TABLE '+@tablename +' ADD CONSTRAINT '+ @constraint_name+' DEFAULT '+@column_default+' FOR '+@columnName
		end


		if @sSqlDropDefaultConstraint != ''
		begin
			-- execution de la requ�te droppant la contrainte par d�faut
			print @sSqlDropDefaultConstraint
			exec(  @sSqlDropDefaultConstraint )
		end

		set @sErrorMessage = ''

		-- requ�te transformant le type de la colonne ( par exemple de DateTime en SmallDateTime )
		set @sSql = 'Alter table ' + @tablename +' alter column ' + @columnName + ' ' + @FormatTo
		print @sSql
		begin try
			exec( @sSql )	
		end try
		begin catch
			set @sErrorMessage = 'Il n''a pas �t� possible de convertir la ' + @ColumnName + ' de la table '+@TableName + ' du type ' + @dataType + ' vers ' + @formatTo
			set @sErrorMessage = @sErrorMessage + ' Error ' + convert(varchar,ERROR_NUMBER()) + ' Severity ' + convert(varchar,ERROR_SEVERITY()) + ' State ' + convert(varchar,ERROR_STATE()) + ' Procedure ' + convert(varchar,ERROR_PROCEDURE()) + ' Line ' + convert(varchar,ERROR_LINE() )+ ' Message ' +  convert(varchar,ERROR_MESSAGE()) 
			set @severity = ERROR_SEVERITY()
			set @state = ERROR_STATE()
		end catch

		if @sSqlAddDefaultConstraint != ''
		begin
			-- execution de la requ�te remettant la contrainte par d�faut
			print @sSqlAddDefaultConstraint
			exec(  @sSqlAddDefaultConstraint )
		end 

		-- Dans le cas ou il y a eu une erreur lors de la transformation, on soul�ve une erreur
		if @sErrorMessage != ''
		begin
			if @bRaiseError=1
				RAISERROR ( @sErrorMessage, @severity, @state)
			else
				print 	@sErrorMessage
		end 
	end
end
go

if exists ( select * from sysobjects where name='Capit_sp_DateTimeToSmallDateTime' and xtype = 'P')
drop procedure Capit_sp_DateTimeToSmallDateTime
go
/*
Description
***********
Capit_sp_DateTimeToSmallDateTime  permet de tranformer une colonne de type DateTime en une colonne de Type smalldatetime
Une colonne de type DateTime prend 8 Octets alors qu'un smalldatetime prend 4 octets. On economise donc 4 octets par ligne.
Les colonnes de types datetime peuvent contenir des valeurs du 1er janvier 1753 au 31 d�cembre 9999 avec une pr�cision de 3,33 millisecondes
Les colonnes de types smalldatetime peuvent contenir des valeurs du 1er janvier 1900 au 6 juin 2079 avec une pr�cision � la minute
 
Param�tres
**********
La proc�dure prend 3 param�tres
@tableName : Nom de la table o� se trouve la colonne � transformer
@columnName : Nom de la colonne � transformer
@bRaiseError (optionnel) : Flag indiquant si une erreur doit �tre soulev� lorsque la colonne n'existe pas

D�pendances
***********
Cette proc�dure utilise :
Capit_sp_ConvertFormat
Capit_V_COLUMNS_DEFAULTS

Restrictions
************
Seules les contraintes de type "default" sont actuellement g�r�es
Les scripts ne fonctionnent que pour les bases en Case-Insensitive
Pour faire �voluer cette proc�dure, �crivez � info@capit.net

Exemple
*******
exec Capit_sp_DateTimeToSmallDateTime 'textes', 'd_creation'

*/
create procedure Capit_sp_DateTimeToSmallDateTime
@TableName sysname,
@columnName sysname,
@bRaiseError bit = 0
as
Declare @sErrorMessage varchar(8000)
if not exists ( 
	select 1
	from information_schema.columns 
	where table_name = @TableName
	and column_name = @ColumnName
	and data_type = 'datetime'	)
begin
	set @sErrorMessage = 'La colonne ' + @ColumnName + ' n''existe pas  dans la table '+@TableName + ' ou elle n''est pas de type DateTime '
	if @bRaiseError = 1
	begin
		RAISERROR ( @sErrorMessage, 1, 1)
	end
	else
	begin
		print 	@sErrorMessage
	end
end
else
	exec Capit_sp_ConvertFormat @TableName, @columnName, 'smalldatetime', @bRaiseError
go
if exists ( select * from sysobjects where name='capit_sp_ConvertAllColumns' and xtype = 'P')
drop procedure capit_sp_ConvertAllColumns
go
/*
Description
***********
capit_sp_ConvertAllColumns  permet de tranformer toutes les colonnes d'un type particulier.
Cel� peut �tre utile lorsque l'on veut transformer toutes les colonnes de type DateTime en smalldatetime.
 
Param�tres
**********
La proc�dure prend 2 param�tres
@FormatFrom : de le type de colonnes � transformer
@FormatTo : le type de colonnes cibles

D�pendances
***********
Cette proc�dure utilise :
Capit_sp_ConvertFormat
Capit_V_COLUMNS_DEFAULTS

Restrictions
************
Seules les contraintes de type "default" sont actuellement g�r�es
Les scripts ne fonctionnent que pour les bases en Case-Insensitive
Pour faire �voluer cette proc�dure, �crivez � info@capit.net

Exemples
********
exec capit_sp_ConvertAllColumns 'DateTime','smalldatetime'

*/
create procedure capit_sp_ConvertAllColumns
@FormatFrom sysname,
@FormatTo sysname
as
declare @columnname sysname
declare @tablename sysname

-- cursor listant toutes les colonnes du type recherch�
declare cCol cursor for
	select col.table_name, col.column_name 
	from information_schema.columns col
			inner join information_schema.tables tab
				on col.table_name = tab.table_name
	where col.data_type = @FormatFrom
	and tab.table_type = 'BASE TABLE'
open cCol
fetch next from cCol into @tablename, @columnName

while @@fetch_status = 0
begin
	print 'Convert ' + @tablename +'.' + @columnName + ' from ' + @FormatFrom + ' to ' + @FormatTo
	-- conversion au format cible
	exec Capit_sp_ConvertFormat @tablename, @columnName, @formatTo
	fetch next from cCol into @tablename, @columnName
end
close cCol
deallocate cCol
go
if exists ( select * from sysobjects where name='Capit_sp_DropColumn' and xtype = 'P')
drop procedure Capit_sp_DropColumn
go

/*
Description
***********
Capit_sp_DropColumn  permet de supprimer une colonne d'une table
 
Param�tres
**********
La proc�dure prend 3 param�tres
@tableName : Nom de la table o� se trouve la colonne � transformer
@columnName : Nom de la colonne � transformer
@bRaiseError (optionnel) : Flag indiquant si une erreur doit �tre soulev�e en cas de probl�me

D�pendances
***********
Cette proc�dure utilise :
Capit_V_COLUMNS_DEFAULTS

Restrictions
************
Seules les contraintes de type "default" sont actuellement g�r�es
Les scripts ne fonctionnent que pour les bases en Case-Insensitive
Pour faire �voluer cette proc�dure, �crivez � info@capit.net

Exemple
*******
exec Capit_sp_DropColumn 'textes', 'n_note'

*/
create procedure Capit_sp_DropColumn
@TableName sysname,
@columnName sysname,
@bRaiseError bit = 0
as
declare @sSqlDropDefaultConstraint varchar(8000)
declare @sSql varchar(8000)
declare @constraint_name sysname
Declare @column_default nvarchar(4000)
Declare @sErrorMessage varchar(8000)
declare @dataType sysname
declare @severity tinyint
declare @state tinyint

-- Initialisation

set @dataType = ''
set @column_default= ''
set @sSqlDropDefaultConstraint = ''
set @sSql = ''

-- V�rification de l'existence de la colonne et de son type

select @column_default = isnull(COLUMN_DEFAULT,''), @dataType = DATA_TYPE
			from information_schema.columns 
			where table_name = @TableName
			and column_name = @ColumnName

-- La colonne n'existe pas
if @dataType = ''
begin
	set @sErrorMessage = 'La colonne ' + @ColumnName + ' n''existe pas  dans la table '+@TableName
	if @bRaiseError=1
		RAISERROR ( @sErrorMessage, 1, 1)
	else
		print 	@sErrorMessage
end
else
begin	
	-- dans le cas ou une contrainte par d�faut est pr�sente sur la colonne, il faut la supprimer	
	if @column_default != ''
	begin
	   select @constraint_name = constraint_name
		from Capit_V_COLUMNS_DEFAULTS 
		where table_name = @tablename 
		and column_name = @columnName
			
		-- Construction de l'ordre pour supprimer la contrainte par defaut
		set @sSqlDropDefaultConstraint = 'ALTER TABLE '+@tablename + ' drop CONSTRAINT ' + @constraint_name		
	end

	set @sErrorMessage = ''
	begin try
	
		if @sSqlDropDefaultConstraint != ''
		begin
			-- execution de la requ�te supprimant la contrainte par d�faut
			print @sSqlDropDefaultConstraint
			exec(  @sSqlDropDefaultConstraint )
		end

		-- requ�te supprimant la colonne 
		set @sSql = 'Alter table ' + @tablename +' drop column ' + @columnName 
		print @sSql
		exec( @sSql )	
	end try
	begin catch
			set @sErrorMessage = 'Il n''a pas �t� possible de supprimer la colonne ' + @ColumnName + ' de la table '+@TableName + ' de type ' + @dataType 
			set @sErrorMessage = @sErrorMessage + ' Error ' + convert(varchar,ERROR_NUMBER()) + ' Severity ' + convert(varchar,ERROR_SEVERITY()) + ' State ' + convert(varchar,ERROR_STATE()) + ' Procedure ' + convert(varchar,ERROR_PROCEDURE()) + ' Line ' + convert(varchar,ERROR_LINE() )+ ' Message ' +  convert(varchar,ERROR_MESSAGE()) 
			set @severity = ERROR_SEVERITY()
			set @state = ERROR_STATE()
			if @bRaiseError=1
				RAISERROR ( @sErrorMessage, @severity, @state)
			else
				print 	@sErrorMessage

	end catch

end
go


