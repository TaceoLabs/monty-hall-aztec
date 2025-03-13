use monty_hall::game_state::GameState;

fn main(seed: Field, user_door: u8, switch: bool) -> pub (u8, bool) {
    let game = GameState::init(seed);
    let (game, opened) = GameState::choose_door(game, user_door);
    let win = GameState::switch(game, switch);
    (opened, win)
}
