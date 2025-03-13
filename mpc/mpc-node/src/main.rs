use clap::Parser;
use config::NodeConfig;
use mpc::MpcNode;
use protos::monty_hall::mpc_node_service_server::MpcNodeServiceServer;
use tonic::transport::Server;

mod config;
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
    let config = NodeConfig::parse();
    tracing::info!("serving node on {}", config.bind_addr);
    let mpc_node = MpcNode::init(&config)?;
    let service = MpcNodeServiceServer::new(mpc_node);
    Server::builder()
        .add_service(service)
        .serve(config.bind_addr)
        .await?;
    Ok(())
}
