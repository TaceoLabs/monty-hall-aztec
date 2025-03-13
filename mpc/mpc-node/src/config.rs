use std::{net::SocketAddr, path::PathBuf};

use clap::Parser;

#[derive(Parser)]
pub struct NodeConfig {
    /// The bind addr of the orchestration server
    #[clap(long, env = "NODE_BIND_ADDR")]
    pub bind_addr: SocketAddr,

    /// The bind addr of the orchestration server
    #[clap(long, env = "NODE_CRS_PATH")]
    pub crs_path: PathBuf,
}
