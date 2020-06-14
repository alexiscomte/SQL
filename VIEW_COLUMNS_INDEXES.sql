/*

list the columns included in indexes

alexis.comte@capit.net
*/

CREATE view [dbo].[VIEW_COLUMNS_INDEXES]
as
select 
o.name as table_name, 
col.name as column_name, 
i.name as index_name, 
i.is_unique, 
i.is_primary_key,
i.type as is_clustered, i.type_desc,
c.index_column_id, c.is_descending_key, c.is_included_column,
c.key_ordinal
 from sys.indexes i
	inner join sysobjects o on i.object_id = o.id 
	inner join sys.index_columns c on c.object_id = o.id
			and c.index_id = i.index_id
	inner join syscolumns col on col.id = o.id
			and c.column_id = col.colid



GO


