-- Add up migration script here
CREATE TABLE IF NOT EXISTS monty_hall_game (
                id SERIAL PRIMARY KEY,
                seed BYTEA NOT NULL,
                seed_r BYTEA NOT NULL,
                seed_c BYTEA NOT NULL
);
