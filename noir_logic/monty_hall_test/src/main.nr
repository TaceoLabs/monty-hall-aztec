use monty_hall::game_state::GameState;
use monty_hall::private_state::PrivateState;

fn main(seed: Field, user_door: u8, switch: bool) -> pub (PrivateState<u8>, PrivateState<bool>) {
    // We simulate creating the private state here
    let seed = PrivateState::new(seed);
    let user_door = PrivateState::new(user_door);
    let switch = PrivateState::new(switch);

    let game = GameState::init(seed);
    let (game, opened) = GameState::choose_door(game, user_door);
    let win = GameState::switch(game, switch);
    (opened, win)
}
