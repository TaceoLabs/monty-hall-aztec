use std::sync::Arc;

use co_builder::prelude::{ProverCrs, ZeroKnowledge};
use co_noir::{Bn254, CrsParser, Rep3MpcNet, Utils};
use noirc_artifacts::program::ProgramArtifact;
use protos::monty_hall::mpc_node_service_server::MpcNodeService;
use protos::monty_hall::{NewGameRequest, NewGameResponse};
use tonic::async_trait;

use crate::config::NodeConfig;

const CRS_SIZE: usize = 512;

pub struct MpcNode {
    config: Arc<NodeConfig>,
    crs: ProverCrs<Bn254>,
    init_circuit: ProgramArtifact,
}

impl MpcNode {
    pub(crate) fn init(config: Arc<NodeConfig>) -> eyre::Result<Self> {
        tracing::info!("Reading crs from {}", config.crs_path.display());
        let crs = CrsParser::<Bn254>::get_crs_g1(&config.crs_path, CRS_SIZE, ZeroKnowledge::Yes)?;
        tracing::info!(
            "reading init circuit from {}...",
            config.init_circuit.display()
        );
        let init_circuit = Utils::get_program_artifact_from_file(&config.init_circuit)?;

        Ok(Self {
            config,
            crs,
            init_circuit,
        })
    }
}

#[async_trait]
impl MpcNodeService for MpcNode {
    async fn new_game(
        &self,
        request: tonic::Request<NewGameRequest>,
    ) -> std::result::Result<tonic::Response<NewGameResponse>, tonic::Status> {
        //tracing::info!("lol I got a request by {}", request.into_inner().message);
        //let network_config = self.config.network_config().unwrap();
        //// we need to execute the init circuit
        //tokio::task::spawn_blocking(|| {
        //    tracing::info!("establishiing network...");
        //    // establish network
        //    let network = Rep3MpcNet::new(network_config);
        //    eyre::Ok(())
        //});

        Ok(tonic::Response::new(NewGameResponse {
            message: "KEKW".to_string(),
        }))
    }
}
