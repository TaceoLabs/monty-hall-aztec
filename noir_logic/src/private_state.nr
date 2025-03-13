use super::game_state::GameState;

pub struct PrivateState<D> {
    pub(crate) data: D,
    pub(crate) commitment: Field,
}

pub trait PrivateStateTrait {
    let N: u32;

    fn as_field_array(self) -> [Field; Self::N];
}

impl<D> PrivateState<D>
where
    D: PrivateStateTrait,
{
    // Required to have commitments as public inputs to the main function
    pub fn from_data_and_commitment(data: D, commitment: Field) -> PrivateState<D> {
        PrivateState { data, commitment }
    }

    pub fn new(data: D) -> PrivateState<D> {
        let commitment = Self::commit(data);
        PrivateState { data, commitment }
    }

    pub fn verify(self) -> D {
        assert(self.commitment == Self::commit(self.data));
        self.data
    }

    pub fn commit(data: D) -> Field {
        let data = data.as_field_array();
        PrivateState::<Field>::commit_field_array::<_>(data)
    }
}

impl PrivateState<Field> {
    fn commit_field_array<let N: u32>(data: [Field; N]) -> Field {
        std::hash::poseidon2::Poseidon2::hash(data, N)
    }
}

impl PrivateStateTrait for Field {
    let N: u32 = 1;

    fn as_field_array(self) -> [Field; Self::N] {
        [self]
    }
}

impl PrivateStateTrait for u8 {
    let N: u32 = 1;

    fn as_field_array(self) -> [Field; Self::N] {
        [self as Field]
    }
}

impl PrivateStateTrait for bool {
    let N: u32 = 1;

    fn as_field_array(self) -> [Field; Self::N] {
        [self as Field]
    }
}

impl PrivateStateTrait for GameState {
    let N: u32 = 9;

    fn as_field_array(self) -> [Field; Self::N] {
        [
            self.state,
            self.prng.state[0],
            self.prng.state[1],
            self.prng.state[2],
            self.prng.state[3],
            self.prng.position,
            self.winning_door as Field,
            self.chosen_door as Field,
            self.open_door as Field,
        ]
    }
}
