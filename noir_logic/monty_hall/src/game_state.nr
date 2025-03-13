use super::prng::Prng;

global STATE_INITIALIZED: Field = 0;
global STATE_OPENED_DOOR: Field = 1;

pub struct GameState {
    pub(crate) state: Field,
    pub(crate) prng: Prng,
    pub(crate) winning_door: u8,
    pub(crate) chosen_door: u8,
    pub(crate) open_door: u8,
}

impl GameState {
    pub fn init(seed: Field) -> GameState {
        let mut prng = Prng::init(seed);
        let winning_door = prng.get_field() as u8 % 3;
        // println(f"Winning door: {winning_door}");

        let state = GameState {
            state: STATE_INITIALIZED,
            prng,
            winning_door,
            chosen_door: 0,
            open_door: 0,
        };

        state
    }

    // Returns the opened door and the new game state
    pub fn choose_door(mut state: Self, door: u8) -> (GameState, u8) {
        assert(state.state == STATE_INITIALIZED);
        assert(door < 3);
        state.chosen_door = door;

        // We try avoiding nested if-else statements since we do not support them yet.
        let calc_if_equal = {
            // Winning door == chosen door
            let rand = state.prng.get_field();
            let opened = rand as bool;
            let opened = opened as u8;
            let opened = if state.winning_door == 0 {
                opened + 1
            } else {
                opened
            };
            let opened = if state.winning_door == 1 {
                (opened + 1) % 3
            } else {
                opened
            };
            opened
        };

        let calc_if_not_equal = {
            // Winning door != chosen door
            3 - state.winning_door - door // 0, 1 -> 2; 0, 2 -> 1; 1, 2 -> 0
        };

        state.open_door = if state.winning_door == door {
            calc_if_equal
        } else {
            calc_if_not_equal
        };
        state.state = STATE_OPENED_DOOR;
        let open_door = state.open_door;

        (state, open_door)
    }

    // Returns whether the player won or not
    pub fn switch(state: Self, switch: bool) -> bool {
        assert(state.state == STATE_OPENED_DOOR);

        let user_door = if switch {
            3 - state.chosen_door - state.open_door // 0, 1 -> 2; 0, 2 -> 1; 1, 2 -> 0
        } else {
            state.chosen_door
        };
        user_door == state.winning_door
    }
}

#[test]
fn test_win_no_switch() {
    let seed = 123;
    let choice = 0;
    let switch = false;

    let mut game = GameState::init(seed); // Winning door is 0
    let (game, opened) = GameState::choose_door(game, choice);
    assert(opened != 0);
    assert(GameState::switch(game, switch));
}

#[test]
fn test_win_switch1() {
    let seed = 123;
    let choice = 1;
    let switch = true;

    let mut game = GameState::init(seed); // Winning door is 0
    let (game, opened) = GameState::choose_door(game, choice);
    assert(opened == 2);
    assert(GameState::switch(game, switch));
}

#[test]
fn test_win_switch2() {
    let seed = 123;
    let choice = 2;
    let switch = true;

    let mut game = GameState::init(seed); // Winning door is 0
    let (game, opened) = GameState::choose_door(game, choice);
    assert(opened == 1);
    assert(GameState::switch(game, switch));
}

#[test]
fn test_lose_no_switch1() {
    let seed = 123;
    let choice = 1;
    let switch = false;

    let game = GameState::init(seed); // Winning door is 0
    let (game, opened) = GameState::choose_door(game, choice);
    assert(opened == 2);
    assert(!GameState::switch(game, switch));
}

#[test]
fn test_lose_no_switch2() {
    let seed = 123;
    let choice = 2;
    let switch = false;

    let mut game = GameState::init(seed); // Winning door is 0
    let (game, opened) = GameState::choose_door(game, choice);
    assert(opened == 1);
    assert(!GameState::switch(game, switch));
}

#[test]
fn test_lose_switch() {
    let seed = 123;
    let choice = 0;
    let switch = true;

    let mut game = GameState::init(seed); // Winning door is 0
    let (game, opened) = GameState::choose_door(game, choice);
    assert(opened != 0);
    assert(!GameState::switch(game, switch));
}
