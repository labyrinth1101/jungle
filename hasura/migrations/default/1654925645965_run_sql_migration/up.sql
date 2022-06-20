CREATE OR REPLACE FUNCTION public.edition_artist_owned(edition_row editions)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
SELECT artworks.artist_id = editions.owner_id FROM editions JOIN artworks on editions.artwork_id = artworks.id WHERE editions.id = edition_row.id
$function$;
