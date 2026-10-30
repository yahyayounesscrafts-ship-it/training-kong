return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "check_referer" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"  UUID                         UNIQUE  REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "referer"      TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "check_referer_consumer_id_idx" ON "check_referer" ("consumer_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS check_referer(
        id          uuid PRIMARY KEY,
        created_at  timestamp,
        consumer_id uuid,
        referer     text
      );
      CREATE INDEX IF NOT EXISTS ON check_referer(consumer_id);
    ]],
  },
}
