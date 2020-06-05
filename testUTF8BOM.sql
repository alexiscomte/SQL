drop procedure tutuUTF8BOM
go
create procedure tutuUTF8BOM as
select * from EFFECTIVITE_FILTRE EFF
where 'tutu' like REPLACE(REPLACE(REPLACE(REPLACE(EFF.PN, '%', 'µ%'), '_', 'µ_'), '*', '%'), '?', '_')
go
