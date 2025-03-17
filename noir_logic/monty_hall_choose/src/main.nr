use monty_hall::game_state::GameState;
use pss_utils::private_state::{CommitMetaData, PrivateState};
use std::embedded_curve_ops::EmbeddedCurvePoint;

fn main(
    state: GameState,
    state_r: CommitMetaData<1>,
    state_c: pub Field,
    door: u8,
    door_r: CommitMetaData<2>,
    door_c: pub Field,
    out1_r: CommitMetaData<1>,
    out2_r: CommitMetaData<1>,
    nullifying_key: Field,
    nullifying_pub_key: pub EmbeddedCurvePoint,
) -> pub (Field, Field, Field) {
    let (state, state_nullifier) = PrivateState::from_data_and_commitment(state, state_r, state_c)
        .verify_and_nullify(nullifying_key, nullifying_pub_key);
    let door = PrivateState::from_data_and_commitment(door, door_r, door_c).verify();

    let (state, opened_door) = GameState::choose_door(state, door);

    // TODO how to open the data to the users?
    (
        PrivateState::new(state, out1_r).commitment,
        PrivateState::new(opened_door, out2_r).commitment, state_nullifier,
    )
}
