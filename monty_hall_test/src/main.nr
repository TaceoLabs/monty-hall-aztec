use monty_hall::game_state::GameState;

fn main(seed: Field, user_door: u8, switch: bool) -> pub (u8, bool) {
    let game = GameState::init(seed);
    let (game, opened) = game.choose_door(user_door);
    let win = game.switch(switch);
    (opened, win)
}
