use std::{net::SocketAddr, path::PathBuf};

use clap::Parser;
use co_noir::NetworkConfig;
use mpc_net::config::NetworkConfigFile;
use secrecy::SecretString;

#[derive(Parser)]
pub struct NodeConfig {
    /// The bind addr of the grpc server
    #[clap(long, env = "NODE_BIND_ADDR")]
    pub bind_addr: SocketAddr,

    /// The path to the CRS
    #[clap(long, env = "NODE_CRS_PATH")]
    pub crs_path: PathBuf,

    /// The path to the init circuit
    #[clap(long, env = "NODE_INIT_CIRCUIT")]
    pub init_circuit: PathBuf,

    /// The path to the network config file
    #[clap(long, env = "NODE_NETWORK_CONFIG")]
    pub network_config: PathBuf,

    /// The secret phrase to derive key material
    #[clap(long, env = "NODE_KEY_PHRASE")]
    pub key_phrase: SecretString,
}

impl NodeConfig {
    pub(crate) fn network_config(&self) -> eyre::Result<NetworkConfig> {
        let toml = std::fs::read_to_string(&self.network_config)?;
        let config_file = toml::from_str::<NetworkConfigFile>(&toml)?;
        tracing::info!(
            "reading from config file: {}",
            self.network_config.display()
        );
        Ok(NetworkConfig::try_from(config_file)?)
    }
}
