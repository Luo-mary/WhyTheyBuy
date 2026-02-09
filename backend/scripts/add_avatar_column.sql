-- Migration to add avatar_url column to users table
-- Run this if the table already exists:
-- psql -U postgres -d whytheybuy -f scripts/add_avatar_column.sql

ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(500);
