pub struct Prng {
    pub(crate) state: [Field; 4],
    pub(crate) position: Field,
}

impl Prng {
    pub(crate) fn init(seed: Field) -> Prng {
        Prng { state: [seed, 0, 0, 0], position: 3 }
    }

    pub(crate) fn get_field(&mut self) -> Field {
        if self.position == 3 {
            self.state = std::hash::poseidon2_permutation(self.state, 4);
            self.position = 0;
        }
        let result = self.state[self.position];
        self.position += 1;
        result
    }
}
