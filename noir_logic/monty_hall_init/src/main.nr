use monty_hall::game_state::{GameState, PrivateStateTrait};
use pss_utils::private_state::{CommitMetaData, PrivateState};

#[oracle(chacha20)]
unconstrained fn store_private_shared_state_oracle<let N: u32>(x: [Field; N]) {}

unconstrained fn store_private_shared_state<let N: u32>(x: [Field; N]) {
    store_private_shared_state_oracle(x);
}

fn main(
    seed: Field,
    seed_r: CommitMetaData<1>,
    seed_c: pub Field,
    out_r: CommitMetaData<1>,
) -> pub Field {
    let seed = PrivateState::from_data_and_commitment(seed, seed_r, seed_c).verify();

    let state = GameState::init(seed);
    unsafe { store_private_shared_state(state.as_field_array()) };

    PrivateState::new("game_state", state, out_r).commitment
}
