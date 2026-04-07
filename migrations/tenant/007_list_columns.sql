ALTER TABLE collection_schemas
  ADD COLUMN IF NOT EXISTS list_columns TEXT[] DEFAULT NULL;
