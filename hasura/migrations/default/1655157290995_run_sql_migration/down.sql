-- Could not auto-generate a down migration.
-- Please write an appropriate down migration for the SQL below:
-- CREATE OR REPLACE FUNCTION public.trigger_cancel_bid()
--  RETURNS trigger
--  LANGUAGE plpgsql
-- AS $function$
-- BEGIN
--     IF NEW.type = 'cancelled_bid' THEN
--         UPDATE editions SET bid_id = (SELECT transactions.id
--         FROM transactions
--         JOIN editions ON transactions.edition_id = editions.id
--         WHERE transactions.edition_id = NEW.edition_id
--         AND transactions.type = 'bid'
--         AND (transactions.created_at > editions.transferred_at
--         OR editions.transferred_at IS NULL)
--         ORDER BY amount DESC
--         LIMIT 1
--         ) where id = NEW.edition_id;
--     END IF;
--
--   RETURN NEW;
-- END;
-- $function$;
