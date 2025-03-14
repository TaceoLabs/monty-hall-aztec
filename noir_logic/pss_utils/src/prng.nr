use super::private_state::PrivateStateTrait;

// Follows the SAFE API [https://eprint.iacr.org/2023/522.pdf](https://eprint.iacr.org/2023/522.pdf)
pub struct Prng {
    pub(crate) state: [Field; 4],
    pub(crate) position: Field,
}

impl Prng {
    pub fn init(seed: Field) -> Prng {
        Prng { state: [seed, 0, 0, 0], position: 3 }
    }

    pub fn get_field(&mut self) -> Field {
        if self.position == 3 {
            self.state = std::hash::poseidon2_permutation(self.state, 4);
            self.position = 0;
        }
        let result = self.state[self.position];
        self.position += 1;
        result
    }
}

impl PrivateStateTrait for Prng {
    let N: u32 = 5;

    fn as_field_array(self) -> [Field; Self::N] {
        [self.state[0], self.state[1], self.state[2], self.state[3], self.position]
    }
}
