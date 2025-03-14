use monty_hall::game_state::GameState;
use pss_utils::private_state::PrivateState;

fn main(
    state: GameState,
    state_r: Field,
    state_c: pub Field,
    door: u8,
    door_r: Field,
    door_c: pub Field,
    out1_r: Field,
    out2_r: Field,
) -> pub (Field, Field) {
    let state = PrivateState::from_data_and_commitment(state, state_r, state_c).verify();
    let door = PrivateState::from_data_and_commitment(door, door_r, door_c).verify();

    let (state, opened_door) = GameState::choose_door(state, door);

    // TODO how to open the data to the users?
    (PrivateState::new(state, out1_r).commitment, PrivateState::new(opened_door, out2_r).commitment)
}
