use super::commit::Commit;

fn array_concat<T, let N: u32, let M: u32>(
    separator: T,
    array1: [T; N],
    array2: [T; M],
) -> [T; N + M + 1] {
    let mut result = [separator; N + M + 1];
    for i in 0..N {
        result[i + 1] = array1[i];
    }
    for i in 0..M {
        result[i + N + 1] = array2[i];
    }
    result
}

pub struct CommitMetaData<let N: u32> {
    pub(crate) data: [Field; N], // In the Aztec infrastrucutre it is the owners address and the storage slot, i.e., [owner, storage_slot]
}

pub struct PrivateState<D, let N: u32> {
    pub(crate) data: D,
    pub(crate) meta: CommitMetaData<N>,
    pub commitment: Field,
}

pub trait PrivateStateTrait {
    let N: u32;

    fn as_field_array(self) -> [Field; Self::N];
}

impl<D, let N: u32> PrivateState<D, N>
where
    D: PrivateStateTrait,
{

    // Required to have commitments as public inputs to the main function
    pub fn from_data_and_commitment(
        data: D,
        meta: CommitMetaData<N>,
        commitment: Field,
    ) -> PrivateState<D, N> {
        PrivateState { data, meta, commitment }
    }

    pub fn new(data: D, meta: CommitMetaData<N>) -> PrivateState<D, N> {
        let commitment = Self::commit(data, meta);
        PrivateState { data, meta, commitment }
    }

    pub fn verify(self) -> D {
        assert(self.commitment == Self::commit(self.data, self.meta));
        self.data
    }

    // Aztec compatible: [https://docs.aztec.network/aztec/smart_contracts/functions/attributes#implementing-notes](https://docs.aztec.network/aztec/smart_contracts/functions/attributes#implementing-notes)
    pub fn commit(data: D, meta: CommitMetaData<N>) -> Field {
        let GENERATOR_INDEX__NOTE_HASH: u32 = 1;

        let data = data.as_field_array();
        let packed = array_concat(GENERATOR_INDEX__NOTE_HASH as Field, data, meta.data);
        Commit::poseidon2_hash(packed)
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
