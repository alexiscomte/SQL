/*

get the details of the defaults constaints

alexis.comte@capit.net

*/

CREATE VIEW [dbo].[VIEW_DEFAULT_CONSTRAINTS]
AS SELECT c.name AS   constraint_name
		, o.name AS   table_name
		, col.name AS column_name
		, def.column_default
   FROM sysobjects AS c
	   INNER JOIN sysconstraints AS sc
		   ON sc.constid = c.id
	   INNER JOIN sysobjects AS o
		   ON sc.id = o.id
	   INNER JOIN syscolumns AS col
		   ON col.id = o.id
			  AND col.colid = sc.colid
	   INNER JOIN information_schema.columns AS def
		   ON def.table_name = o.name
			  AND def.column_name = col.name
   WHERE c.xtype = 'D';

GO


