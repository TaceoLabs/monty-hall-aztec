use super::prng::Prng;

global STATE_INITIALIZED: Field = 0;
global STATE_OPENED_DOOR: Field = 1;
global STATE_FINISHED: Field = 2;

pub struct GameState {
    pub(crate) state: Field,
    pub(crate) prng: Prng,
    pub(crate) winning_door: Field,
    pub(crate) chosen_door: Field,
    pub(crate) open_door: Field,
}

impl GameState {
    pub fn init(seed: Field) -> GameState {
        let mut prng = Prng::init(seed);
        let winning_door = prng.get_field();

        GameState {
            state: STATE_INITIALIZED,
            prng,
            winning_door,
            chosen_door: Field::default(),
            open_door: Field::default(),
        }
    }

    // Returns the opened door
    pub fn choose_door(&mut self, door: Field) -> Field {
        assert(self.state == STATE_INITIALIZED);
        assert(door as u8 < 3);

        // We try avoiding nested if-else statements since we do not support them yet.
        let calc_if_equal = {
            // Winning door == chosen door
            let rand = self.prng.get_field();
            let opened = rand as bool;
            let opened = opened as Field;
            let opened = if self.winning_door == 0 {
                opened + 1
            } else {
                opened
            };
            let opened = if self.winning_door == 1 {
                ((opened + 1) as u8 % 3) as Field
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

        self.open_door
    }

    // Returns whether the player won or not
    pub fn switch(&mut self, switch: bool) -> bool {
        assert(self.state == STATE_OPENED_DOOR);

        let user_door = if switch {
            3 - self.chosen_door - self.open_door // 0, 1 -> 2; 0, 2 -> 1; 1, 2 -> 0
        } else {
            self.chosen_door
        };
        self.state = STATE_FINISHED;
        user_door == self.winning_door
    }
}
