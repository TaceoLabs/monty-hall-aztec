use dep::aztec::macros::aztec; //ouside of the contract block
mod pop_capsule;
mod taceo_note;
mod private_shared_mutable;

/// This is a small demo on how private shared state could look like on Aztec,
/// It so far only contains logic on how MPC networks can create private state on Aztec, including verifying all required proofs (input-to-output relations, verifying commitments of inputs and outputs, verifying nullifiers, verifying the relation of the nullifying private key to the public key).
/// TODO: What is still missing is general smart contract logic to bind a game to a user address and verifying that the functions are called in correct order. Since this is independent to private shared state considerations, this was not the focus of this demo.
#[aztec]
contract MontyHall {
    use crate::pop_capsule::pop_capsule;
    use crate::private_shared_mutable::PrivateSharedMutable;
    use crate::taceo_note::TACEONote;

    use aztec::macros::{functions::{initializer, private, public}, storage::storage};
    use aztec::prelude::{PrivateImmutable, PublicImmutable, PublicMutable};

    use std::{embedded_curve_ops::EmbeddedCurvePoint, hash::poseidon2};
    use uint_note::uint_note::UintNote;
    use aztec::protocol_types::traits::Packable;

    global PROOF_SIZE: u32 = 463; // iirc this is the UH sizes
    global HONK_IDENTIFIER: u32 = 1; // iirc this is the UH identifier
    global VK_SIZE: u32 = 128;
    global GAME_INITIALIZED: u8 = 0;
    global GAME_STARTED: u8 = 1;
    global GAME_CHOSEN_DOOR: u8 = 2;
    global GAME_SWITCHED_OR_NOT: u8 = 3;
    global GAME_OPENED_DOOR: u8 = 4;
    global GAME_DONE: u8 = 4;
    global NUMBER_OF_VK_HASHES: u32 = 3;

    #[storage]
    struct Storage<Context> {
        vk_hash: PublicImmutable<[Field; NUMBER_OF_VK_HASHES], Context>,
        nullifying_pk: PublicImmutable<EmbeddedCurvePoint, Context>,
        seed: PrivateImmutable<TACEONote, Context>,
        game_state: PrivateSharedMutable<TACEONote, Context>,
        chosen_door: PrivateImmutable<UintNote, Context>,
        opened_door: PrivateImmutable<TACEONote, Context>,
        switched_door: PrivateImmutable<UintNote, Context>,
        win: PrivateImmutable<TACEONote, Context>,
        game_phase: PublicMutable<u8, Context>,
    }

    /// Called by the MPC-network. It commits to a random seed on chain which is the basis for a new game. Furthermore, a nullifying pk is committed to on chain.
    #[initializer]
    #[private]
    fn init_game(
        seed_c: Field,
        vk_hashes: [Field; NUMBER_OF_VK_HASHES],
        nullifying_pk: EmbeddedCurvePoint,
    ) {
        storage.seed.initialize(TACEONote::new(nullifying_pk, seed_c)).discard();
        // Safety: This is normal Aztec practice?
        unsafe {
            initialize_vk_hashes(vk_hashes);
            write_game_phase(GAME_INITIALIZED);
            initialize_nullifying_pks(nullifying_pk);
        }
    }

    #[public]
    fn initialize_vk_hashes(vk_hashes: [Field; NUMBER_OF_VK_HASHES]) {
        storage.vk_hash.initialize(vk_hashes);
    }

    #[public]
    fn write_game_phase(phase: u8) {
        storage.game_phase.write(phase);
    }

    #[public]
    fn initialize_nullifying_pks(nullifying_pk: EmbeddedCurvePoint) {
        storage.nullifying_pk.initialize(nullifying_pk);
    }

    /// Called by the MPC network, it starts a new game by proving that it has derived a game from the seed.
    // The proof is a UltraHonk proof (later on with ZK once the recursion is allowed for that). The proof itself needs to contain relations for checking the commitment for the seed, deriving the gamestate from the seed and verifying the commitment of the gamestate.
    #[private]
    fn start_game(
        game_state_c: Field,
    ) {
        // Safety: This is normal Aztec practice?
        let vk: [Field; VK_SIZE] = unsafe { pop_capsule() };
        // Safety: This is normal Aztec practice?
        let proof: [Field; PROOF_SIZE] = unsafe { pop_capsule() };
        let vk_hash: [Field; NUMBER_OF_VK_HASHES] = storage.vk_hash.read();
        let vk_hash_computed = compute_vk_hash(vk);
        let seed_c = storage.seed.get_note();
        assert(vk_hash_computed == vk_hash[0]);
        std::verify_proof_with_type(
            vk,
            proof,
            [game_state_c, seed_c.get_commitment()],
            vk_hash_computed,
            HONK_IDENTIFIER,
        );
        let _ = storage.game_state.initialize(TACEONote::new(
            storage.nullifying_pk.read(),
            game_state_c,
        ));
        // Safety: This is normal Aztec practice?
        unsafe {
            write_game_phase(GAME_STARTED);
        }
    }

    /// This is called by the player. The player chooses a door to be opened. This function is independent to private shared state, but the user needs to tell the MPC network all inputs (i.e., the door), as well as all information that is needed to verify the commitment of the door which is stored on chain.
    #[private]
    fn choose_door(x: u8) {
        assert(x < 3);
        storage.chosen_door.initialize(UintNote::new(x as u128, context.msg_sender())).discard();
        // Safety: This is normal Aztec practice?
        unsafe {
            write_game_phase(GAME_CHOSEN_DOOR);
        }
    }

    /// This is called by the MPC network. It opens a door to the player after this one has chosen another. The MPC network needs to prove correctness of the new game state and opened door. Consequently the proof needs to contain:
    /// - verifying all input commitments.
    /// - proving the relation from the previous game-state and the user input to the new game-state and user output.
    /// - creating the nullifier for the old game-state.
    /// - proving the relation of the nullifying key to the nullifiying public key
    /// - proving the correctness of the provided commitments.
    #[private]
    fn open_door(new_game_state_c: Field, opened_door_c: Field, game_state_nullifier: Field) {
        // Safety: This is normal Aztec practice?
        let vk: [Field; VK_SIZE] = unsafe { pop_capsule() };
        // Safety: This is normal Aztec practice?
        let proof: [Field; PROOF_SIZE] = unsafe { pop_capsule() };
        let vk_hash_computed = compute_vk_hash(vk);
        let vk_hash: [Field; NUMBER_OF_VK_HASHES] = storage.vk_hash.read();
        assert(vk_hash_computed == vk_hash[1]);
        let game_state_hash = storage.game_state.get_note_hash();
        let nullifying_key = storage.nullifying_pk.read().pack();

        std::verify_proof_with_type(
            vk,
            proof,
            [game_state_hash, new_game_state_c, opened_door_c, game_state_nullifier, nullifying_key[0], nullifying_key[1], nullifying_key[2]],
            vk_hash[1],
            HONK_IDENTIFIER,
        );

        storage.game_state.replace(
            TACEONote::new(storage.nullifying_pk.read(), new_game_state_c),
            game_state_nullifier,
        ).discard();
        // For this demo we just create a new Note for the opened door. In a real application, the opened door needs to be communicated to the player. There are multiple ways to do so:
        // - Use an encrypted log
        // - Let the MPC network (somehow) send it (encrypted) to the player.
        // In the first case the player owns the private state. In latter case, we can write a "claim function" that creates a private state for the user if he knows the input and randomness for the commitment created on chain. Thus this claim function has data and randomness as input, computes the commitment and asserts it to be equal to the commitment of the opened door. It then creates a new private state for the user.
         storage.opened_door.initialize(
            TACEONote::new(storage.nullifying_pk.read(), opened_door_c)).discard();
        // Safety: This is normal Aztec practice?
        unsafe {
            write_game_phase(GAME_OPENED_DOOR);
        }
    }

    /// This is done by the player. The player chooses whether to switch its chosen door or not. This function is independent to private shared state, but the user needs to tell the MPC network all inputs (i.e., yes/no), as well as all information that is needed to verify the commitment of the door which is stored on chain.
    #[private]
    fn switch_door(x: bool) {
        // Safety: This is normal Aztec practice?
        unsafe {
            write_game_phase(GAME_SWITCHED_OR_NOT);
        }
        storage.switched_door.initialize(UintNote::new(x as u128, context.msg_sender())).discard();
    }

    /// This is called by the MPC network. It opens a door to the player after this one has chosen another. The MPC network needs to prove correctness of the new game state and opened door. Consequently the proof needs to contain:
    /// - verifying all input commitments.
    /// - proving the relation from the previous game-state and the user input to user output.
    /// - creating the nullifier for the old game-state.
    /// - proving the relation of the nullifying key to the nullifiying public key
    /// - proving the correctness of the provided commitments.
    #[private]
    fn finish_game(win_c: Field, game_state_nullifier: Field) {
        // Safety: This is normal Aztec practice?
        let vk: [Field; VK_SIZE] = unsafe { pop_capsule() };
        // Safety: This is normal Aztec practice?
        let proof: [Field; PROOF_SIZE] = unsafe { pop_capsule() };
        let vk_hash_computed = compute_vk_hash(vk);
        let vk_hash: [Field; NUMBER_OF_VK_HASHES] = storage.vk_hash.read();
        assert(vk_hash_computed == vk_hash[2]);
        let game_state_hash = storage.game_state.get_note_hash();
        let nullifying_key = storage.nullifying_pk.read().pack();

        std::verify_proof_with_type(
            vk,
            proof,
            [game_state_hash, win_c, game_state_nullifier, nullifying_key[0], nullifying_key[1], nullifying_key[2]],
            vk_hash[1],
            HONK_IDENTIFIER,
        );

        // In a real game we would have to compute a new game state so we can nullify the old one here and keep one for future games. We ignore this for this demo.
        // storage.game_state.replace(
            // TACEONote::new(storage.nullifying_pk.read(), 0),
            // game_state_nullifier,
        // ).discard();

        // For this demo we just create a new Note for the user if it won. In a real application, the content of this note needs to be communicated to the player. There are multiple ways to do so:
        // - Use an encrypted log
        // - Let the MPC network (somehow) send it (encrypted) to the player.
        // In the first case the player owns the private state. In latter case, we can write a "claim function" that creates a private state for the user if he knows the input and randomness for the commitment created on chain. Thus this claim function has data and randomness as input, computes the commitment and asserts it to be equal to the commitment of the opened door. It then creates a new private state for the user.
         storage.win.initialize(
            TACEONote::new(storage.nullifying_pk.read(), win_c)).discard();
        // Safety: This is normal Aztec practice?
        unsafe {
            write_game_phase(GAME_DONE);
        }
    }

    #[contract_library_method]
    fn compute_vk_hash(vk: [Field; 128]) -> Field {
        poseidon2::Poseidon2::hash(vk, 128)
    }
}
