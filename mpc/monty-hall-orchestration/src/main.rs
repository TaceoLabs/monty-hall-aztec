use std::{path::PathBuf, sync::Arc};

use axum::Router;
use clap::{Args, Parser};
use co_noir::{Bn254, CrsParser, VerifyingKey, VerifyingKeyBarretenberg};
use config::ServerConfig;
use eyre::Context;
use mpc_node::MpcNodeHandle;
use tower_http::cors::CorsLayer;

mod config;
mod error;
mod mpc_node;
mod routes;

fn install_tracing() {
    use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();
}

#[derive(Clone)]
pub struct AppState {
    pub node0: MpcNodeHandle,
    pub node1: MpcNodeHandle,
    pub node2: MpcNodeHandle,
    pub verifier_crs: ark_bn254::G2Affine,
    pub init_vk_path: PathBuf,
}

#[tokio::main]
async fn main() -> eyre::Result<()> {
    install_tracing();

    let config = ServerConfig::parse();

    let verifier_crs = CrsParser::<Bn254>::get_crs_g2(config.verifier_crs)?;

    let (node0, node1, node2) = tokio::join!(
        mpc_node::connect(&config.mpc_nodes[0]),
        mpc_node::connect(&config.mpc_nodes[1]),
        mpc_node::connect(&config.mpc_nodes[2])
    );
    let node0 = node0?;
    let node1 = node1?;
    let node2 = node2?;

    let app_state = AppState {
        node0,
        node1,
        node2,
        verifier_crs,
        init_vk_path: config.init_vk_path.clone(),
    };

    let app = Router::new()
        .nest("/api/", routes::create_routes(app_state))
        .layer(CorsLayer::permissive());

    tracing::info!("starting app listening on {}", config.bind_addr);
    let listener = tokio::net::TcpListener::bind(&config.bind_addr).await?;
    axum::serve(listener, app).await.context("axum died")?;
    Ok(())
}
