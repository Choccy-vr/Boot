-- Ensure increment_field_value casts row_id to the table's id column type
drop function if exists public.increment_field_value(text, text, text, bigint);
create or replace function public.increment_field_value(
	table_name text,
	field_name text,
	row_id text,
	increment_amount bigint
)
returns void
language plpgsql
security definer
set search_path = public
as
$$
declare
	id_type text;
begin
	select pg_catalog.format_type(a.atttypid, a.atttypmod)
		into id_type
	from pg_catalog.pg_attribute a
		join pg_catalog.pg_class c on c.oid = a.attrelid
		join pg_catalog.pg_namespace n on n.oid = c.relnamespace
	where n.nspname = 'public'
		and c.relname = table_name
		and a.attname = 'id'
		and a.attnum > 0
		and not a.attisdropped;

	if id_type is null then
		raise exception 'Column "id" not found on table %.%', 'public', table_name;
	end if;

	execute format(
		'update %I.%I
			 set %I = coalesce(%I, 0) + $1,
					 updated_at = now()
		 where id = $2::%s',
		'public',
		table_name,
		field_name,
		field_name,
		id_type
	)
	using increment_amount, row_id;
end;
$$;
