use ark_serialize::CanonicalDeserialize;
use axum::{
    extract::{Path, State},
    http::StatusCode,
};
use co_builder::prelude::ZeroKnowledge;
use co_noir::{Bn254, Poseidon2Sponge, UltraHonk, VerifyingKey, VerifyingKeyBarretenberg};
use ultrahonk::prelude::HonkProof;

use crate::{AppState, error::ApiResult};

pub async fn sample_root_rand(State(state): State<AppState>) -> ApiResult<StatusCode> {
    tracing::info!("creating new randomness!");
    let (response0, response1, response2) = tokio::join!(
        state.node0.sample_root_rand(),
        state.node1.sample_root_rand(),
        state.node2.sample_root_rand()
    );
    let response0 = response0?;
    let response1 = response1?;
    let response2 = response2?;

    if response0.seed_c != response1.seed_c || response1.seed_c != response2.seed_c {
        Err(eyre::eyre!("seed_commitment differ!"))?;
    }
    let seed_commitment =
        ark_bn254::Fr::deserialize_compressed(response0.seed_c.as_slice()).unwrap();
    tracing::info!("got commitment to seed!");
    tracing::info!("{seed_commitment}");
    tracing::info!("sending seed commitment to chain (soon tm)");
    // TODO SEND THIS ON CHAIN
    Ok(StatusCode::OK)
}

pub async fn init_game(State(state): State<AppState>) -> ApiResult<StatusCode> {
    let (response0, response1, response2) = tokio::join!(
        state.node0.new_game(),
        state.node1.new_game(),
        state.node2.new_game()
    );
    let response0 = response0?;
    let response1 = response1?;
    let response2 = response2?;
    if response0.proof != response1.proof || response1.proof != response2.proof {
        Err(eyre::eyre!("proofs differ!"))?;
    }
    if response0.game_state_c != response1.game_state_c
        || response1.game_state_c != response2.game_state_c
    {
        Err(eyre::eyre!("seed_commitment differ!"))?;
    }

    let init_vk = std::fs::read(state.init_vk_path).unwrap();
    let init_vk = VerifyingKeyBarretenberg::<Bn254>::from_buffer(&init_vk).unwrap();

    let init_vk = VerifyingKey::from_barrettenberg_and_crs(init_vk, state.verifier_crs);
    let proof = HonkProof::from_buffer(&response0.proof).expect("can deser proof");

    let result =
        UltraHonk::<_, Poseidon2Sponge>::verify(proof, init_vk, ZeroKnowledge::Yes).unwrap();

    if result {
        tracing::info!("retrieved proofs! Now sending them on chain (soon tm)");
    } else {
        tracing::error!("proofs do not verify! Rejected")
    }
    // TODO SEND THIS ON CHAIN
    Ok(StatusCode::OK)
}

pub async fn reveal_door(State(state): State<AppState>) -> ApiResult<StatusCode> {
    todo!()
}
