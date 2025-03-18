# monty-hall-aztec

This is a small demo for private shared state on Aztec. It is not yet finished, but the existing code base should give an idea of how we envision private shared state to be integrated in the Aztec infrastructure.

- The `contract` folder contains the smart contract that is put on chain.
- The `noir_logic` folder contains the code executed by the MPC network to produce co-SNARKs. It encodes the intented functionality of the use case, while the smart contract only takes care of verifying proofs and managing the private states.
- The `mpc` folder contains the code for seting up and running the MPC nodes.
