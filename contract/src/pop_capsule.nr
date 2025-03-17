#[oracle(popCapsule)]
unconstrained fn pop_capsule_oracle<let N: u32>() -> [Field; N] {}

// A capsule is a "blob" of data that is passed to the contract through an oracle.
pub unconstrained fn pop_capsule<let N: u32>() -> [Field; N] {
    pop_capsule_oracle()
}
