// Follows the SAFE API [https://eprint.iacr.org/2023/522.pdf](https://eprint.iacr.org/2023/522.pdf)
// It is not used in the Aztec infrastructure
pub struct Commit {}

impl Commit {
    fn absorb(data: Field, state: &mut [Field; 4], position: &mut Field) {
        if *position == 3 {
            *state = std::hash::poseidon2_permutation(*state, 4);
            *position = 0;
        }
        state[*position] += data;
        *position += 1;
    }

    pub(crate) fn commit_field_array<let N: u32>(data: [Field; N]) -> Field {
        let d = 0x4142;
        let absorb = 0x80000000 + N as Field;
        let squeeze = 1;
        let t = d + squeeze * 65536 + absorb * 281474976710656;
        let mut state = [0, 0, 0, t];
        let mut position = 0;

        // Absorb
        for i in 0..N {
            Self::absorb(data[i], &mut state, &mut position);
        }

        // Squeeze
        std::hash::poseidon2_permutation(state, 4)[0]
    }

    pub(crate) fn poseidon2_hash<let N: u32>(inputs: [Field; N]) -> Field {
        std::hash::poseidon2::Poseidon2::hash(inputs, N)
    }
}
