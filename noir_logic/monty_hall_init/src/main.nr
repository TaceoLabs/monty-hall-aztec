use monty_hall::game_state::GameState;
use pss_utils::private_state::{CommitMetaData, PrivateState};

fn main(
    seed: Field,
    seed_r: CommitMetaData<1>,
    seed_c: pub Field,
    out_r: CommitMetaData<1>,
) -> pub Field {
    let seed = PrivateState::from_data_and_commitment(seed, seed_r, seed_c).verify();

    let state = GameState::init(seed);

    // TODO how to open the data to the users?
    PrivateState::new(state, out_r).commitment
}
