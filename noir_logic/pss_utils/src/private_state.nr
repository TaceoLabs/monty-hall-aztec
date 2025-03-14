use super::commit::Commit;

pub struct PrivateState<D> {
    pub(crate) data: D,
    pub(crate) rand: Field,
    pub commitment: Field,
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
    pub fn from_data_and_commitment(data: D, rand: Field, commitment: Field) -> PrivateState<D> {
        PrivateState { data, rand, commitment }
    }

    pub fn new(data: D, rand: Field) -> PrivateState<D> {
        let commitment = Self::commit(data, rand);
        PrivateState { data, rand, commitment }
    }

    pub fn verify(self) -> D {
        assert(self.commitment == Self::commit(self.data, self.rand));
        self.data
    }

    pub fn commit(data: D, rand: Field) -> Field {
        let data = data.as_field_array();
        Commit::commit_field_array::<_>(data, rand)
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
