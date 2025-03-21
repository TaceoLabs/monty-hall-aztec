use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::Instant;

use ark_ff::One as _;
use co_builder::prelude::{ProverCrs, ZeroKnowledge};
use co_noir::{
    Bn254, CrsParser, Poseidon2Sponge, Rep3AcvmType, Rep3CoUltraHonk, Rep3MpcNet, Utils,
};
use mpc_core::protocols::rep3::Rep3PrimeFieldShare;
use mpc_core::protocols::rep3::network::{IoContext, Rep3Network};
use noirc_artifacts::program::ProgramArtifact;
use protos::monty_hall::mpc_node_service_server::MpcNodeService;
use protos::monty_hall::{
    InitGameRequest, InitGameResponse, RevealDoorRequest, RevealDoorResponse, SampleRandRequest,
    SampleRandResponse,
};
use tonic::async_trait;
use ultrahonk::prelude::HonkProof;

use crate::config::NodeConfig;
use crate::data_store::DbStore;

const CRS_SIZE: usize = 4096;

type AcvmType = Rep3AcvmType<ark_bn254::Fr>;
pub type ArithmeticShare = Rep3PrimeFieldShare<ark_bn254::Fr>;

pub struct MpcNode {
    config: Arc<NodeConfig>,
    crs: Arc<ProverCrs<Bn254>>,
    db_store: DbStore,
    commit_circuit: ProgramArtifact,
    init_circuit: ProgramArtifact,
}

impl MpcNode {
    pub(crate) fn init(config: Arc<NodeConfig>, db_store: DbStore) -> eyre::Result<Self> {
        tracing::info!("Reading crs from {}", config.crs_path.display());
        let crs = CrsParser::<Bn254>::get_crs_g1(&config.crs_path, CRS_SIZE, ZeroKnowledge::Yes)?;
        tracing::info!(
            "reading commit circuit from {}...",
            config.commit_circuit.display()
        );
        let commit_circuit = Utils::get_program_artifact_from_file(&config.commit_circuit)?;
        tracing::info!(
            "reading init circuit from {}...",
            config.init_circuit.display()
        );
        let init_circuit = Utils::get_program_artifact_from_file(&config.init_circuit)?;

        Ok(Self {
            config,
            db_store,
            crs: Arc::new(crs),
            commit_circuit,
            init_circuit,
        })
    }
}

pub(crate) struct InitState {
    pub(crate) proof: HonkProof<ark_bn254::Fr>,
    pub(crate) game_state_r: ArithmeticShare,
    pub(crate) game_state_c: ark_bn254::Fr,
}

pub(crate) struct RootRandomness {
    pub(crate) seed: ArithmeticShare,
    pub(crate) seed_r: ArithmeticShare,
    pub(crate) seed_c: ark_bn254::Fr,
}

impl MpcNode {
    fn sample_root_rand(
        network: Rep3MpcNet,
        commit_circuit: ProgramArtifact,
    ) -> eyre::Result<RootRandomness> {
        tracing::info!("creating io context");
        let mut io_context = IoContext::init(network)?;

        tracing::info!("squeezing elements");
        let (seed_a, seed_b) = io_context.random_fes::<ark_bn254::Fr>();
        let (seed_r_a, seed_r_b) = io_context.random_fes::<ark_bn254::Fr>();
        let seed = Rep3PrimeFieldShare::new(seed_a, seed_b);
        let seed_r = Rep3PrimeFieldShare::new(seed_r_a, seed_r_b);
        let network = io_context.network;
        let (seed_c, _) = Self::commit(&seed, &seed_r, commit_circuit, network)?;
        Ok(RootRandomness {
            seed,
            seed_r,
            seed_c,
        })
    }

    fn init_game(
        crs: Arc<ProverCrs<Bn254>>,
        network: Rep3MpcNet,
        root_randomness: RootRandomness,
        init_circuit: ProgramArtifact,
    ) -> eyre::Result<InitState> {
        tracing::info!("creating io context");
        let mut io_context = IoContext::init(network)?;

        tracing::info!("squeezing elements");
        let (out_r_a, out_r_b) = io_context.random_fes::<ark_bn254::Fr>();
        let out_r = Rep3PrimeFieldShare::new(out_r_a, out_r_b);
        let network = io_context.network;

        let constraint_system = Utils::get_constraint_system_from_artifact(&init_circuit, true);

        // generate the proof
        let mut input_share = BTreeMap::default();
        input_share.insert(
            "seed".to_string(),
            Rep3AcvmType::Shared(root_randomness.seed.clone()),
        );
        input_share.insert(
            "seed_r".to_string(),
            Rep3AcvmType::Shared(root_randomness.seed_r.clone()),
        );
        input_share.insert(
            "seed_c".to_string(),
            Rep3AcvmType::Public(root_randomness.seed_c),
        );
        input_share.insert("out_r".to_string(), Rep3AcvmType::Shared(out_r.clone()));

        let time = Instant::now();
        let (witness_share, net) =
            co_noir::generate_witness_rep3(input_share, init_circuit, network)?;
        let elapsed_witness = time.elapsed();

        // hardcoded for the time being
        let game_state_c = if let Rep3AcvmType::Public(commitment) = witness_share[4] {
            commitment
        } else {
            eyre::bail!("THIS SHOULD NOT HAPPEN - COMMITMENT IS NOT ON 4 ANYMORE");
        };

        // generate proving key and vk
        let (pk, net) =
            co_noir::generate_proving_key_rep3(net, &constraint_system, witness_share, false)?;

        let elapsed_pk = time.elapsed();

        // generate proof
        let (proof, _) =
            Rep3CoUltraHonk::<_, _, Poseidon2Sponge>::prove(net, pk, &crs, ZeroKnowledge::No)?;

        let elapsed_proof = time.elapsed();

        tracing::info!("executed init circuit!");
        tracing::info!(
            "total time: {}.{} secs",
            elapsed_proof.as_secs(),
            elapsed_proof.subsec_nanos()
        );

        tracing::info!(
            "wit extension: {}.{} secs",
            elapsed_witness.as_secs(),
            elapsed_witness.subsec_nanos()
        );

        let elapsed_pk = elapsed_pk - elapsed_witness;
        tracing::info!(
            "pk creation: {}.{} secs",
            elapsed_pk.as_secs(),
            elapsed_pk.subsec_nanos()
        );

        let elapsed_proof = elapsed_proof - elapsed_pk;
        tracing::info!(
            "proof creation: {}.{} secs",
            elapsed_proof.as_secs(),
            elapsed_proof.subsec_nanos()
        );

        Ok(InitState {
            proof,
            game_state_r: out_r,
            game_state_c,
        })
    }

    fn extract_game_state(witness: &[AcvmType]) -> Vec<()> {
        if let AcvmType::Shared(state) = witness[11] {}
        if let AcvmType::Shared(state) = witness[12] {}
        if let AcvmType::Shared(state) = witness[13] {}
        if let AcvmType::Shared(state) = witness[14] {}
        if let AcvmType::Shared(state) = witness[15] {}

        todo!()
    }

    fn commit(
        data: &ArithmeticShare,
        rand: &ArithmeticShare,
        commit_circuit: ProgramArtifact,
        network: Rep3MpcNet,
    ) -> eyre::Result<(ark_bn254::Fr, Rep3MpcNet)> {
        let mut input_share = BTreeMap::default();
        input_share.insert("x".to_string(), Rep3AcvmType::Shared(data.to_owned()));
        input_share.insert("meta".to_string(), Rep3AcvmType::Shared(rand.to_owned()));
        let start = Instant::now();
        // TODO we need a better way to simply execute a noir program and obtain
        // the outputs
        let (result_witness_share, net) =
            co_noir::generate_witness_rep3(input_share, commit_circuit, network)?;
        let elapsed = start.elapsed();
        tracing::info!(
            "Generate witness took {}.{}",
            elapsed.as_secs(),
            elapsed.subsec_nanos()
        );
        if let Rep3AcvmType::Public(commitment) = result_witness_share[2] {
            Ok((commitment, net))
        } else {
            eyre::bail!("THIS SHOULD NOT HAPPEN - COMMITMENT IS NOT ON 2 ANYMORE");
        }
    }
}

#[async_trait]
impl MpcNodeService for MpcNode {
    async fn sample_rand(
        &self,
        _: tonic::Request<SampleRandRequest>,
    ) -> Result<tonic::Response<SampleRandResponse>, tonic::Status> {
        let network_config = self.config.network_config().unwrap();
        let commit_circuit = self.commit_circuit.clone();
        tracing::info!("Started to sample root randomness!");
        // we need to sample some randomness and commit to it in MPC
        // The network can't run in tokio runtime because it creates a
        // runtime internally. Therefore we need to do this
        // roundtrip to sync land and back
        let time = Instant::now();
        let result = tokio::task::spawn_blocking(|| {
            tracing::info!("establishing network...");
            let net = Rep3MpcNet::new(network_config)?;
            tracing::info!("success!");
            Self::sample_root_rand(net, commit_circuit)
        })
        .await
        .expect("can join");
        let elapsed = time.elapsed();
        tracing::info!(
            "took {}.{} in total",
            elapsed.as_secs(),
            elapsed.subsec_nanos()
        );

        let result = match result {
            Ok(result) => result,
            Err(err) => {
                tracing::error!("{err:#?}");
                return Err(tonic::Status::internal("checks logs something broke"));
            }
        };
        let seed_c = self.db_store.store_root_rand(result).await.unwrap();
        Ok(tonic::Response::new(SampleRandResponse { seed_c }))
    }
    async fn init_game(
        &self,
        _: tonic::Request<InitGameRequest>,
    ) -> std::result::Result<tonic::Response<InitGameResponse>, tonic::Status> {
        let network_config = self.config.network_config().unwrap();
        let init_circuit = self.init_circuit.clone();
        let crs = Arc::clone(&self.crs);
        let root_randomess = self
            .db_store
            .load_root_rand()
            .await
            .expect("can load from DB");
        // we need to execute the init circuit
        // The network can't run in tokio runtime because it creates a
        // runtime internally. Therefore we need to do this
        // roundtrip to sync land and back
        let time = Instant::now();
        let result = tokio::task::spawn_blocking(|| {
            tracing::info!("establishing network...");
            let net = Rep3MpcNet::new(network_config)?;
            tracing::info!("success!");
            Self::init_game(crs, net, root_randomess, init_circuit)
        })
        .await
        .expect("can join");
        let elapsed = time.elapsed();
        tracing::info!(
            "total MPC work {}.{}",
            elapsed.as_secs(),
            elapsed.subsec_nanos()
        );

        let result = match result {
            Ok(result) => result,
            Err(err) => {
                tracing::error!("{err:#?}");
                return Err(tonic::Status::internal("checks logs something broke"));
            }
        };
        let serialized = self
            .db_store
            .init_monty_hall(result)
            .await
            .expect("can store into DB");
        Ok(tonic::Response::new(InitGameResponse {
            proof: serialized.proof,
            game_state_c: serialized.game_state_c,
        }))
    }
    async fn reveal_door(
        &self,
        _: tonic::Request<RevealDoorRequest>,
    ) -> Result<tonic::Response<RevealDoorResponse>, tonic::Status> {
        todo!()
    }
}
