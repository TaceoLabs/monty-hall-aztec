use std::sync::Arc;

use clap::Parser;
use config::NodeConfig;
use crypto_device::CryptoDevice;
use data_store::DbStore;
use mpc::MpcNode;
use protos::monty_hall::mpc_node_service_server::MpcNodeServiceServer;
use tonic::transport::Server;

mod config;
mod crypto_device;
mod data_store;
mod mpc;

fn install_tracing() {
    use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();
}

#[tokio::main]
async fn main() -> eyre::Result<()> {
    install_tracing();
    let config = Arc::new(NodeConfig::parse());
    let crypto_device = CryptoDevice::init(&config);
    let db_store = DbStore::init(&config).await?;
    tracing::info!("serving node on {}", config.bind_addr);
    let mpc_node = MpcNode::init(Arc::clone(&config), db_store)?;
    let service = MpcNodeServiceServer::new(mpc_node);
    Server::builder()
        .add_service(service)
        .serve(config.bind_addr)
        .await?;
    Ok(())
}
