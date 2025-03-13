use monty_hall::game_state::GameState;
use monty_hall::private_state::PrivateState;

fn main(state: GameState, state_c: pub Field, switch: bool, switch_c: pub Field) -> pub Field {
    let state = PrivateState::from_data_and_commitment(state, state_c).verify();
    let switch = PrivateState::from_data_and_commitment(switch, switch_c).verify();

    let win = GameState::switch(state, switch);

    // TODO how to open the data to the users?
    PrivateState::new(win).commitment
}
