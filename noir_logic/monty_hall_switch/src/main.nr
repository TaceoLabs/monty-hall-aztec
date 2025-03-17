use monty_hall::game_state::GameState;
use pss_utils::private_state::{CommitMetaData, PrivateState};

fn main(
    state: GameState,
    state_r: CommitMetaData<1>,
    state_c: pub Field,
    switch: bool,
    switch_r: CommitMetaData<2>,
    switch_c: pub Field,
    out_r: CommitMetaData<1>,
    nullifying_key: Field,
) -> pub (Field, Field) {
    let (state, state_nullifier) = PrivateState::from_data_and_commitment(state, state_r, state_c)
        .verify_and_nullify(nullifying_key);
    let switch = PrivateState::from_data_and_commitment(switch, switch_r, switch_c).verify();

    let win = GameState::switch(state, switch);

    // TODO how to open the data to the users?
    (PrivateState::new(win, out_r).commitment, state_nullifier)
}
