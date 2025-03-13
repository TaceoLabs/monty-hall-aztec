use std::net::SocketAddr;

use clap::Parser;

#[derive(Parser)]
pub struct ServerConfig {
    /// The bind addr of the orchestration server
    #[clap(long, env = "SMPC_BIND_ADDR")]
    pub bind_addr: SocketAddr,

    /// The addresses of the mpc nodes
    #[clap(long, env = "SMPC_MPC_NODES", value_delimiter = ',')]
    pub mpc_nodes: Vec<String>,
}
