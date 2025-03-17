use pss_utils::{private_state::{CommitMetaData, PrivateState}};

fn main(x: Field, meta: CommitMetaData<1>) -> pub Field {
    PrivateState::commit(x, meta)
}

