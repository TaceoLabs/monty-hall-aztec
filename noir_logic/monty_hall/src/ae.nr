pub struct AE {}

// Absorb 2, squeeze 1, absorb 1, squeeze 1, domainsep = 0x4142
// [0x80000002, 0x00000001, 0x80000001, 0x00000001, 0x4142]
global T1: Field = 0x800000020000000180000001000000014142;

impl AE {
    // Returns ciphertext and tag
    pub(crate) fn encrypt1(data: Field, key: Field, nonce: Field) -> (Field, Field) {
        let mut state = std::hash::poseidon2_permutation([key, nonce, 0, T1], 4);
        let ciphertext = data + state[0];
        state[0] = ciphertext;
        let tag = std::hash::poseidon2_permutation(state, 4)[0];
        (ciphertext, tag)
    }

    pub(crate) fn decrypt1(ciphertext: Field, tag: Field, key: Field, nonce: Field) -> Field {
        let mut state = std::hash::poseidon2_permutation([key, nonce, 0, T1], 4);
        let plaintext = ciphertext - state[0];
        state[0] = ciphertext;
        let tag2 = std::hash::poseidon2_permutation(state, 4)[0];
        assert(tag == tag2);
        plaintext
    }
}

#[test]
fn encrypt_decrypt1() {
    let data = 0x123;
    let key = 0x456;
    let nonce = 0x789;
    let (ciphertext, tag) = AE::encrypt1(data, key, nonce);
    let plaintext = AE::decrypt1(ciphertext, tag, key, nonce);
    assert(data == plaintext);
}

#[test(should_fail)]
fn encrypt_decrypt1_faulty() {
    let data = 0x123;
    let key = 0x456;
    let nonce = 0x789;
    let (ciphertext, tag) = AE::encrypt1(data, key, nonce);
    let plaintext = AE::decrypt1(ciphertext, tag, key, nonce + 1);
    assert(data == plaintext);
}
