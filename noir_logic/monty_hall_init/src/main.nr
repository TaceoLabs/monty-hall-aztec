use monty_hall::game_state::GameState;
use monty_hall::private_state::PrivateState;

fn main(seed: Field, seed_r: Field, seed_c: pub Field, out_r: Field) -> pub Field {
    let seed = PrivateState::from_data_and_commitment(seed, seed_r, seed_c).verify();

    let state = GameState::init(seed);

    // TODO how to open the data to the users?
    PrivateState::new(state, out_r).commitment
}
