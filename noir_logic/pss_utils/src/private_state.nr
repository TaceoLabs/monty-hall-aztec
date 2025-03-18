use super::{commit::Commit, dh};
use std::embedded_curve_ops::EmbeddedCurvePoint;

#[oracle(TACEO_store)]
unconstrained fn store_private_state_inner<let N: u32, let S: u32>(name: str<S>, d: [Field; N]) {}

unconstrained fn store_private_state<let N: u32, let S: u32>(name: str<S>, d: [Field; N]) {
    store_private_state_inner(name, d)
}

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

// In the Aztec infrastrucutre it is the owners address and the storage slot, i.e., [owner, storage_slot]
// The MPC network however only adds a random value alongside the data, since we do not have the concept of storage slots
pub struct CommitMetaData<let N: u32> {
    pub(crate) data: [Field; N],
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

    pub fn new<let S: u32>(name: str<S>, data: D, meta: CommitMetaData<N>) -> PrivateState<D, N> {
        let commitment = Self::commit(data, meta);
        // SAFETY: we store the private state in MPC
        unsafe {
            store_private_state(name, data.as_field_array())
        }

        PrivateState { data, meta, commitment }
    }

    pub fn verify(self) -> D {
        let calc_commitment = Self::commit(self.data, self.meta);
        // println(calc_commitment);
        assert(self.commitment == calc_commitment);
        self.data
    }

    // Returns the data and the nullifier
    pub fn verify_and_nullify(
        self,
        secret_key: Field,
        public_key: EmbeddedCurvePoint,
    ) -> (D, Field) {
        let data = self.verify();
        let nullifier = PrivateState::<D, N>::compute_nullifier(self.commitment, secret_key);
        let (_, pk) = dh::generate_ephemeral_key_pair(secret_key);
        assert(pk == public_key);

        (data, nullifier)
    }

    // Aztec compatible: [https://docs.aztec.network/aztec/smart_contracts/functions/attributes#implementing-notes](https://docs.aztec.network/aztec/smart_contracts/functions/attributes#implementing-notes)
    pub fn commit(data: D, meta: CommitMetaData<N>) -> Field {
        let GENERATOR_INDEX__NOTE_HASH: u32 = 1;

        let data = data.as_field_array();
        let packed = array_concat(GENERATOR_INDEX__NOTE_HASH as Field, data, meta.data);
        Commit::poseidon2_hash(packed)
    }

    // Aztec compatible: [https://docs.aztec.network/aztec/smart_contracts/functions/attributes#implementing-notes](https://docs.aztec.network/aztec/smart_contracts/functions/attributes#implementing-notes)
    pub fn compute_nullifier(commitment: Field, secret_key: Field) -> Field {
        let GENERATOR_INDEX__NOTE_NULLIFIER: u32 = 53;

        let packed = [GENERATOR_INDEX__NOTE_NULLIFIER as Field, commitment, secret_key];
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
