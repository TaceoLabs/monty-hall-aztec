use std::{net::SocketAddr, path::PathBuf};

use clap::Parser;

#[derive(Parser)]
pub struct ServerConfig {
    /// The bind addr of the orchestration server
    #[clap(long, env = "SMPC_BIND_ADDR")]
    pub bind_addr: SocketAddr,

    /// The addresses of the mpc nodes
    #[clap(long, env = "SMPC_MPC_NODES", value_delimiter = ',')]
    pub mpc_nodes: Vec<String>,

    /// Path to vk for init circuit
    #[clap(long, env = "SMPC_INIT_CIRCUIT_VK", value_delimiter = ',')]
    pub init_vk_path: PathBuf,

    /// Path to the verifier crs
    #[clap(long, env = "SMPC_VERIFIER_CRS", value_delimiter = ',')]
    pub verifier_crs: PathBuf,
}
