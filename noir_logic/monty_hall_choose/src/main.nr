use monty_hall::game_state::GameState;
use monty_hall::private_state::PrivateState;

fn main(state: GameState, state_c: pub Field, door: u8, door_c: pub Field) -> pub (Field, Field) {
    let state = PrivateState::from_data_and_commitment(state, state_c).verify();
    let door = PrivateState::from_data_and_commitment(door, door_c).verify();

    let (state, opened_door) = GameState::choose_door(state, door);

    // TODO how to open the data to the users?
    (PrivateState::new(state).commitment, PrivateState::new(opened_door).commitment)
}
