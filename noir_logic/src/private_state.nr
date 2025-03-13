use super::game_state::GameState;

pub struct PrivateState<D> {
    pub(crate) data: D,
    pub(crate) commitment: Field,
}

pub trait PrivateStateTrait {
    fn commit(self) -> Field;
}

impl<D> PrivateState<D>
where
    D: PrivateStateTrait,
{
    pub fn new(data: D) -> PrivateState<D> {
        let commitment = data.commit();
        PrivateState { data, commitment }
    }

    pub fn verify(self) {
        assert(self.commitment == self.data.commit());
    }
}

impl PrivateState<Field> {
    fn commit_field_array<let N: u32>(data: [Field; N]) -> Field {
        std::hash::poseidon2::Poseidon2::hash(data, N)
    }
}

impl PrivateStateTrait for Field {
    fn commit(self) -> Field {
        PrivateState::<Field>::commit_field_array::<1>([self])
    }
}

impl PrivateStateTrait for u8 {
    fn commit(self) -> Field {
        PrivateState::<Field>::commit_field_array::<1>([self as Field])
    }
}

impl PrivateStateTrait for bool {
    fn commit(self) -> Field {
        PrivateState::<Field>::commit_field_array::<1>([self as Field])
    }
}

impl PrivateStateTrait for GameState {
    fn commit(self) -> Field {
        let data = self.as_field_array();
        PrivateState::<Field>::commit_field_array::<_>(data)
    }
}
