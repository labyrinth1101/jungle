CREATE OR REPLACE FUNCTION public.trigger_update_bid()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE bid INTEGER;
BEGIN
    IF NEW.type = 'bid' THEN
        SELECT transactions.amount
        FROM transactions
        JOIN editions ON transactions.edition_id = editions.id
        WHERE transactions.edition_id = NEW.edition_id
        AND transactions.type = 'bid'
        AND transactions.id != NEW.id
        AND (transactions.created_at > editions.transferred_at
        OR editions.transferred_at IS NULL)
        ORDER BY amount DESC
        LIMIT 1
        INTO bid;
        
      IF bid IS NULL OR NEW.amount > bid THEN
        UPDATE editions SET bid_id = NEW.id WHERE id = NEW.edition_id;
      END IF;
    END IF;

  RETURN NEW;
END;
$function$;
