use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use sqlx::{PgPool, migrate::Migrator, postgres::PgPoolOptions, prelude::FromRow};
use toml::ser;

use crate::{
    config::NodeConfig,
    mpc::{ArithmeticShare, InitNewGameResult, RootRandomness},
};

static MIGRATOR: Migrator = sqlx::migrate!("./migrations");

pub(super) struct DbStore {
    pool: PgPool,
}

#[derive(Default, FromRow)]
struct RootRandomnessSerialized {
    seed: Vec<u8>,
    seed_r: Vec<u8>,
    seed_c: Vec<u8>,
}

impl RootRandomnessSerialized {
    fn new() -> Self {
        Self::default()
    }
}

impl TryFrom<RootRandomness> for RootRandomnessSerialized {
    type Error = eyre::Report;
    fn try_from(value: RootRandomness) -> eyre::Result<Self> {
        let mut rand = RootRandomnessSerialized::new();
        value.seed.serialize_uncompressed(&mut rand.seed)?;
        value.seed_r.serialize_uncompressed(&mut rand.seed_r)?;
        value.seed_c.serialize_uncompressed(&mut rand.seed_c)?;
        Ok(rand)
    }
}

impl From<RootRandomnessSerialized> for RootRandomness {
    fn from(value: RootRandomnessSerialized) -> Self {
        let seed = ArithmeticShare::deserialize_uncompressed(value.seed.as_slice())
            .expect("correctly in DB");
        let seed_r = ArithmeticShare::deserialize_uncompressed(value.seed_r.as_slice())
            .expect("correctly in DB");
        let seed_c = ark_bn254::Fr::deserialize_uncompressed(value.seed_c.as_slice())
            .expect("correctly in DB");
        Self {
            seed_c,
            seed,
            seed_r,
        }
    }
}

impl DbStore {
    pub(super) async fn init(config: &NodeConfig) -> eyre::Result<DbStore> {
        tracing::debug!("connecting to {}", config.postgres_url);
        let pool = PgPoolOptions::new().connect(&config.postgres_url).await?;
        MIGRATOR.run(&pool).await.expect("Couldn't migrate db");
        Ok(DbStore { pool })
    }

    pub(crate) async fn store_root_rand(&self, root_rand: RootRandomness) -> eyre::Result<Vec<u8>> {
        let serialized = RootRandomnessSerialized::try_from(root_rand)?;
        // for simplicity we just delete the old randomness
        sqlx::query("TRUNCATE TABLE monty_hall_game ")
            .execute(&self.pool)
            .await?;
        sqlx::query("INSERT INTO monty_hall_game (seed, seed_r, seed_c) VALUES ($1, $2, $3)")
            .bind(serialized.seed.as_slice())
            .bind(serialized.seed_r.as_slice())
            .bind(serialized.seed_c.as_slice())
            .execute(&self.pool)
            .await?;

        Ok(serialized.seed_c)
    }

    pub(crate) async fn load_root_rand(&self) -> eyre::Result<RootRandomness> {
        let row = sqlx::query_as::<_, RootRandomnessSerialized>(
            "SELECT seed, seed_r, seed_c FROM monty_hall_game",
        )
        .fetch_one(&self.pool)
        .await?;
        Ok(RootRandomness::from(row))
    }
}
