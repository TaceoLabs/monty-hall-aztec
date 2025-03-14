// Follows the SAFE API [https://eprint.iacr.org/2023/522.pdf](https://eprint.iacr.org/2023/522.pdf)
pub struct AE {}

// Absorb 2, squeeze 1, absorb 1, squeeze 1, domainsep = 0x4142
// [0x80000002, 0x00000001, 0x80000001, 0x00000001, 0x4142]
global T1: Field = 0x800000020000000180000001000000014142;
// Absorb 2, squeeze 2, absorb 2, squeeze 1, domainsep = 0x4142
// [0x80000002, 0x00000002, 0x80000002, 0x00000001, 0x4142]
global T2: Field = 0x800000020000000280000002000000014142;
// Absorb 2, squeeze 3, absorb 3, squeeze 1, domainsep = 0x4142
// [0x80000002, 0x00000003, 0x80000003, 0x00000001, 0x4142]
global T3: Field = 0x800000020000000380000003000000014142;

impl AE {
    // Returns ciphertext and tag
    pub(crate) fn encrypt1(mut data: Field, key: Field, nonce: Field) -> (Field, Field) {
        let mut state = std::hash::poseidon2_permutation([key, nonce, 0, T1], 4);
        state[0] += data;
        data = state[0];
        let tag = std::hash::poseidon2_permutation(state, 4)[0];
        (data, tag)
    }

    pub(crate) fn decrypt1(ciphertext: Field, tag: Field, key: Field, nonce: Field) -> Field {
        let mut state = std::hash::poseidon2_permutation([key, nonce, 0, T1], 4);
        let plaintext = ciphertext - state[0];
        state[0] = ciphertext;
        let tag2 = std::hash::poseidon2_permutation(state, 4)[0];
        assert(tag == tag2);
        plaintext
    }

    // Returns ciphertext and tag
    pub(crate) fn encrypt2(mut data: [Field; 2], key: Field, nonce: Field) -> ([Field; 2], Field) {
        let mut state = std::hash::poseidon2_permutation([key, nonce, 0, T2], 4);
        for i in 0..2 {
            state[i] += data[i];
            data[i] = state[i];
        }
        let tag = std::hash::poseidon2_permutation(state, 4)[0];
        (data, tag)
    }

    pub(crate) fn decrypt2(
        mut ciphertext: [Field; 2],
        tag: Field,
        key: Field,
        nonce: Field,
    ) -> [Field; 2] {
        let mut state = std::hash::poseidon2_permutation([key, nonce, 0, T2], 4);
        for i in 0..2 {
            let plaintext = ciphertext[i] - state[i];
            state[i] = ciphertext[i];
            ciphertext[i] = plaintext;
        }
        let tag2 = std::hash::poseidon2_permutation(state, 4)[0];
        assert(tag == tag2);
        ciphertext
    }

    // Returns ciphertext and tag
    pub(crate) fn encrypt3(mut data: [Field; 3], key: Field, nonce: Field) -> ([Field; 3], Field) {
        let mut state = std::hash::poseidon2_permutation([key, nonce, 0, T3], 4);
        for i in 0..3 {
            state[i] += data[i];
            data[i] = state[i];
        }
        let tag = std::hash::poseidon2_permutation(state, 4)[0];
        (data, tag)
    }

    pub(crate) fn decrypt3(
        mut ciphertext: [Field; 3],
        tag: Field,
        key: Field,
        nonce: Field,
    ) -> [Field; 3] {
        let mut state = std::hash::poseidon2_permutation([key, nonce, 0, T3], 4);
        for i in 0..3 {
            let plaintext = ciphertext[i] - state[i];
            state[i] = ciphertext[i];
            ciphertext[i] = plaintext;
        }
        let tag2 = std::hash::poseidon2_permutation(state, 4)[0];
        assert(tag == tag2);
        ciphertext
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

#[test]
fn encrypt_decrypt2() {
    let data = [0x123, 0x456];
    let key = 0x789;
    let nonce = 0xabc;
    let (ciphertext, tag) = AE::encrypt2(data, key, nonce);
    let plaintext = AE::decrypt2(ciphertext, tag, key, nonce);
    assert(data == plaintext);
}

#[test(should_fail)]
fn encrypt_decrypt2_faulty() {
    let data = [0x123, 0x456];
    let key = 0x789;
    let nonce = 0xabc;
    let (ciphertext, tag) = AE::encrypt2(data, key, nonce);
    let plaintext = AE::decrypt2(ciphertext, tag, key, nonce + 1);
    assert(data == plaintext);
}

#[test]
fn encrypt_decrypt3() {
    let data = [0x123, 0x456, 0x789];
    let key = 0xabc;
    let nonce = 0xdef;
    let (ciphertext, tag) = AE::encrypt3(data, key, nonce);
    let plaintext = AE::decrypt3(ciphertext, tag, key, nonce);
    assert(data == plaintext);
}

#[test(should_fail)]
fn encrypt_decrypt3_faulty() {
    let data = [0x123, 0x456, 0x789];
    let key = 0xabc;
    let nonce = 0xdef;
    let (ciphertext, tag) = AE::encrypt3(data, key, nonce);
    let plaintext = AE::decrypt3(ciphertext, tag, key, nonce + 1);
    assert(data == plaintext);
}
