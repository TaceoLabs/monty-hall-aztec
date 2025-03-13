use std::{net::SocketAddr, path::PathBuf};

use clap::Parser;
use co_noir::NetworkConfig;
use mpc_net::config::NetworkConfigFile;

#[derive(Parser)]
pub struct NodeConfig {
    /// The bind addr of the grpc server
    #[clap(long, env = "NODE_GRPC_BIND_ADDR")]
    pub grpc_bind_addr: SocketAddr,

    /// The bind addr of the grpc server
    #[clap(long, env = "NODE_MPC_BIND_ADDR")]
    pub mpc_bind_addr: SocketAddr,

    /// The path to the CRS
    #[clap(long, env = "NODE_CRS_PATH")]
    pub crs_path: PathBuf,

    /// The party id of this node
    #[clap(long, env = "NODE_PARTY_ID")]
    pub party_id: usize,

    /// The addresses of all MPC nodes (including this node)
    #[clap(long, env = "NODE_PEER_ADDRESSES", value_delimiter = ',')]
    pub peer_addresses: Vec<String>,

    /// The network config file
    #[clap(long, env = "NODE_NETWORK_CONFIG")]
    pub network_config: PathBuf,
}

impl NodeConfig {
    pub(crate) fn network_config(&self) -> NetworkConfig {
        //NetworkConfig::new(self.party_id, self.mpc_bind_addr, key, parties);

        todo!()
    }
}
