-- Add up migration script here
CREATE TABLE IF NOT EXISTS root_rand (
                id SERIAL PRIMARY KEY,
                seed BYTEA NOT NULL,
                seed_r BYTEA NOT NULL,
                seed_c BYTEA NOT NULL
);

CREATE TABLE IF NOT EXISTS monty_hall_game_init_state (
                id SERIAL PRIMARY KEY,
                proof BYTEA NOT NULL,
                game_state_r BYTEA NOT NULL,
                game_state_c BYTEA NOT NULL
);
