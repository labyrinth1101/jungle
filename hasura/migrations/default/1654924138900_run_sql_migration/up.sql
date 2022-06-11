CREATE OR REPLACE FUNCTION public.edition_last_tx(edition_row editions)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE
AS $function$
    SELECT max(transactions.created_at)
    FROM transactions
    WHERE transactions.edition_id = edition_row.id
$function$;
