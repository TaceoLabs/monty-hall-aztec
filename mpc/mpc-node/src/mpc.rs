use co_builder::prelude::{ProverCrs, ZeroKnowledge};
use co_noir::{Bn254, CrsParser, NetworkConfig, Rep3MpcNet};
use protos::monty_hall::mpc_node_service_server::MpcNodeService;
use protos::monty_hall::{NewGameRequest, NewGameResponse};
use tonic::async_trait;

use crate::config::NodeConfig;

const CRS_SIZE: usize = 512;

pub struct MpcNode {
    crs: ProverCrs<Bn254>,
    network: Rep3MpcNet,
}

impl MpcNode {
    pub(crate) fn init(config: &NodeConfig) -> eyre::Result<Self> {
        let crs = CrsParser::<Bn254>::get_crs_g1(&config.crs_path, CRS_SIZE, ZeroKnowledge::Yes)?;

        //let network = Rep3MpcNet::new(config)
        todo!()
        //  Ok(Self { crs })
    }
}

#[async_trait]
impl MpcNodeService for MpcNode {
    async fn new_game(
        &self,
        request: tonic::Request<NewGameRequest>,
    ) -> std::result::Result<tonic::Response<NewGameResponse>, tonic::Status> {
        tracing::info!("lol I got a request by {}", request.into_inner().message);
        //let net = Rep3MpcNet::new(config)
        Ok(tonic::Response::new(NewGameResponse {
            message: "KEKW".to_string(),
        }))
    }
}
