use monty_hall::game_state::GameState;
use pss_utils::private_state::{CommitMetaData, PrivateState};
use std::embedded_curve_ops::EmbeddedCurvePoint;

fn main(
    state: GameState,
    state_r: CommitMetaData<1>,
    state_c: pub Field,
    switch: bool,
    switch_r: CommitMetaData<2>,
    switch_c: pub Field,
    out_r: CommitMetaData<1>,
    nullifying_key: Field,
    nullifying_pub_key: pub EmbeddedCurvePoint,
) -> pub (Field, Field) {
    let (state, state_nullifier) = PrivateState::from_data_and_commitment(state, state_r, state_c)
        .verify_and_nullify(nullifying_key, nullifying_pub_key);
    let switch = PrivateState::from_data_and_commitment(switch, switch_r, switch_c).verify();

    let win = GameState::switch(state, switch);

    (PrivateState::new("win", win, out_r).commitment, state_nullifier)
}
