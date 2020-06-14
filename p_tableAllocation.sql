

/*

Will give the size of tables and indexed and number of rows of each table.
This allow to understand how the size is used inside a database

alexis.comte@capit.net

*/

CREATE PROCEDURE [dbo].[p_tableAllocation]
AS
BEGIN
	SELECT o.name
		 , SUM(reserved_page_count) * 8 / 1024 AS [reserved space (Mb) ]
		 , SUM(used_page_count) * 8 / 1024 AS     [index space (Mb) ]
		 , SUM(CASE
				   WHEN(index_id < 2)
					   THEN(in_row_data_page_count + lob_used_page_count + row_overflow_used_page_count)
				   ELSE lob_used_page_count + row_overflow_used_page_count
			   END) * 8 / 1024 AS                 [data space (Mb)]
		 , SUM(CASE
				   WHEN(index_id < 2)
					   THEN row_count
				   ELSE 0
			   END) AS                            [Rows]
	FROM sys.dm_db_partition_stats AS s
		INNER JOIN sysobjects AS o
			ON s.object_id = o.id
	GROUP BY o.name
	ORDER BY 2 DESC;
END;

GO


