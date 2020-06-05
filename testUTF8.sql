drop procedure tutuUTF8 
go
create procedure tutuUTF8 as
select * from EFFECTIVITE_FILTRE EFF
where 'tutu' like REPLACE(REPLACE(REPLACE(REPLACE(EFF.PN, '%', 'µ%'), '_', 'µ_'), '*', '%'), '?', '_')
go
