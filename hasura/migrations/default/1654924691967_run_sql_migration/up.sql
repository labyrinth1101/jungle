CREATE OR REPLACE VIEW "public"."recentactivity" AS 
 SELECT t1.id,
    t1.hash,
    t1.edition_id,
    t1.type,
    t1.amount,
    t1.user_id,
    t1.created_at,
    t1.asset,
    t1.psbt,
    t1.confirmed,
    t1.bid_id,
    t1.contract
   FROM (transactions t1
     JOIN ( SELECT t.edition_id,
            max(t.created_at) AS max_created_at
           FROM (transactions t
             JOIN editions e ON ((e.id = t.edition_id)))
          WHERE ((t.type = ANY (ARRAY['purchase'::text, 'bid'::text, 'creation'::text, 'accept'::text])) AND ((e.asking_asset IS NOT NULL) OR (e.transferred_at IS NOT NULL)))
          GROUP BY t.edition_id) t2 ON (((t1.edition_id = t2.edition_id) AND (t1.created_at = t2.max_created_at))))
  ORDER BY t1.created_at DESC
 LIMIT 200;
