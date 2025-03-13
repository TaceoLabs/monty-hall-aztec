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

        GameState {
            state: STATE_INITIALIZED,
            prng,
            winning_door,
            chosen_door: 0,
            open_door: 0,
        }
    }

    // Returns the opened door and the new game state
    pub fn choose_door(mut self, door: u8) -> (GameState, u8) {
        assert(self.state == STATE_INITIALIZED);
        assert(door < 3);
        self.chosen_door = door;

        // We try avoiding nested if-else statements since we do not support them yet.
        let calc_if_equal = {
            // Winning door == chosen door
            let rand = self.prng.get_field();
            let opened = rand as bool;
            let opened = opened as u8;
            let opened = if self.winning_door == 0 {
                opened + 1
            } else {
                opened
            };
            let opened = if self.winning_door == 1 {
                (opened + 1) % 3
            } else {
                opened
            };
            opened
        };

        let calc_if_not_equal = {
            // Winning door != chosen door
            3 - self.winning_door - door // 0, 1 -> 2; 0, 2 -> 1; 1, 2 -> 0
        };

        self.open_door = if self.winning_door == door {
            calc_if_equal
        } else {
            calc_if_not_equal
        };
        self.state = STATE_OPENED_DOOR;
        let open_door = self.open_door;

        (self, open_door)
    }

    // Returns whether the player won or not
    pub fn switch(self, switch: bool) -> bool {
        assert(self.state == STATE_OPENED_DOOR);

        let user_door = if switch {
            3 - self.chosen_door - self.open_door // 0, 1 -> 2; 0, 2 -> 1; 1, 2 -> 0
        } else {
            self.chosen_door
        };
        user_door == self.winning_door
    }
}

#[test]
fn test_win_no_switch() {
    let seed = 123;
    let mut game = GameState::init(seed); // Winning door is 00
    let (game, opened) = game.choose_door(0);
    assert(opened != 0);
    assert(game.switch(false));
}

#[test]
fn test_win_switch1() {
    let seed = 123;
    let mut game = GameState::init(seed); // Winning door is 00
    let (game, opened) = game.choose_door(1);
    assert(opened == 2);
    assert(game.switch(true));
}

#[test]
fn test_win_switch2() {
    let seed = 123;
    let mut game = GameState::init(seed); // Winning door is 00
    let (game, opened) = game.choose_door(2);
    assert(opened == 1);
    assert(game.switch(true));
}


#[test]
fn test_lose_no_switch1() {
    let seed = 123;
    let game = GameState::init(seed); // Winning door is 0
    let (game, opened) = game.choose_door(1);
    assert(opened == 2);
    assert(!game.switch(false));
}

#[test]
fn test_lose_no_switch2() {
    let seed = 123;
    let mut game = GameState::init(seed); // Winning door is 00
    let (game, opened) = game.choose_door(2);
    assert(opened == 1);
    assert(!game.switch(false));
}

#[test]
fn test_lose_switch() {
    let seed = 123;
    let mut game = GameState::init(seed); // Winning door is 00
    let (game, opened) = game.choose_door(0);
    assert(opened != 0);
    assert(!game.switch(true));
}
