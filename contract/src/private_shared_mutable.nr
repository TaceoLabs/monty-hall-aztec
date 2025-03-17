use dep::aztec::context::{PrivateContext, UnconstrainedContext};
use dep::aztec::note::{
    lifecycle::create_note,
    note_emission::NoteEmission,
    note_getter::{get_note, view_notes},
    note_interface::{NoteHash, NoteType},
    note_viewer_options::NoteViewerOptions,
};
use dep::aztec::note::{
    retrieved_note::RetrievedNote, utils::compute_note_hash_for_nullify_from_read_request,
};
use dep::aztec::oracle::notes::check_nullifier_exists;
use dep::aztec::protocol_types::{
    constants::GENERATOR_INDEX__INITIALIZATION_NULLIFIER, hash::poseidon2_hash_with_separator,
    traits::Packable,
};
use dep::aztec::state_vars::storage::Storage;

/// When dealing with a private-shared-state that is only known to an MPC-network as a collective group and no indivdual party, issues arise with nullifying a Note.
/// The issue is that in the normal Aztec infrastructure, a Note computes the nullifier during the replace function of a PrivateMutable. However, the nullifier can only be computed when the private nullifying key of the owner is known.
/// Thus, if the nullifying key is only known to the MPC-network as a collective, the nullifier needs to be computed by the MPC-network and given to the nullification process as an input (we also have to make sure that we proof in ZK that the correct nullifying key was used and that the nullifier is correct).
/// This is the reason why we have to implement a PrivateSharedMutable struct and can not use PrivateMutable.
/// PrivateSharedMutable is a copy of [PrivateMutable](https://github.com/AztecProtocol/aztec-packages/blob/master/noir-projects/aztec-nr/aztec/src/state_vars/private_mutable.nr) that replaces calls to compute_nullifier with using a nullifier as an input.
pub struct PrivateSharedMutable<Note, Context> {
    context: Context,
    storage_slot: Field,
}

impl<T, Context, let N: u32> Storage<N> for PrivateSharedMutable<T, Context>
where
    T: Packable<N>,
{
    fn get_storage_slot(self) -> Field {
        self.storage_slot
    }
}

impl<Note, Context> PrivateSharedMutable<Note, Context> {
    pub fn new(context: Context, storage_slot: Field) -> Self {
        assert(storage_slot != 0, "Storage slot 0 not allowed. Storage slots must start from 1.");
        Self { context, storage_slot }
    }

    // The following computation is leaky, in that it doesn't hide the storage slot that has been initialized, nor does it hide the contract address of this contract.
    // When this initialization nullifier is emitted, an observer could do a dictionary or rainbow attack to learn the preimage of this nullifier to deduce the storage slot and contract address.
    // For some applications, leaking the details that a particular state variable of a particular contract has been initialized will be unacceptable.
    // Under such circumstances, such application developers might wish to _not_ use this state variable type.
    // This is especially dangerous for initial assignment to elements of a `Map<AztecAddress, PrivateSharedMutable>` type (for example), because the storage slot often also identifies an actor. e.g.
    // the initial assignment to `my_map.at(msg.sender)` will leak: `msg.sender`, the fact that an element of `my_map` was assigned-to for the first time, and the contract_address.
    // Note: subsequent nullification of this state variable, via the `replace` method will not be leaky, if the `compute_nullifier()` method of the underlying note is designed to ensure privacy.
    // For example, if the `compute_nullifier()` method injects the secret key of a note owner into the computed nullifier's preimage.
    pub fn compute_initialization_nullifier(self) -> Field {
        poseidon2_hash_with_separator(
            [self.storage_slot],
            GENERATOR_INDEX__INITIALIZATION_NULLIFIER,
        )
    }
}

impl<Note, let N: u32> PrivateSharedMutable<Note, &mut PrivateContext>
where
    Note: NoteType + NoteHash + Packable<N>,
{
    pub fn initialize(self, note: Note) -> NoteEmission<Note> {
        // Nullify the storage slot.
        let nullifier = self.compute_initialization_nullifier();
        self.context.push_nullifier(nullifier);

        create_note(self.context, self.storage_slot, note)
    }

    pub fn replace(self, new_note: Note, nullifier: Field) -> NoteEmission<Note> {
        let (prev_retrieved_note, note_hash_for_read_request): (RetrievedNote<Note>, Field) =
            get_note(self.context, self.storage_slot);

        // Nullify previous note.
        self.destroy_note_unsafe_shared(prev_retrieved_note, note_hash_for_read_request, nullifier);

        // Add replacement note.
        create_note(self.context, self.storage_slot, new_note)
    }

    pub fn initialize_or_replace(self, note: Note, nullifier: Field) -> NoteEmission<Note> {
        // Safety: `check_nullifier_exists` is an unconstrained function - we can constrain a true value
        // by providing an inclusion proof of the nullifier, but cannot constrain a false value since
        // a non-inclusion proof would only be valid if done in public.
        // Ultimately, this is not an issue given that we'll either:
        //  - initialize the state variable, which would fail if it was already initialized due to the duplicate
        //    nullifier, or
        //  - replace the current value, which would fail if it was not initialized since we wouldn't be able
        //    to produce an inclusion proof for the current note
        // This means that an honest oracle will assist the prover to produce a valid proof, while a malicious
        // oracle (i.e. one that returns an incorrect value for is_initialized) will simply fail to produce
        // a proof.
        let is_initialized =
            unsafe { check_nullifier_exists(self.compute_initialization_nullifier()) };

        if (!is_initialized) {
            self.initialize(note)
        } else {
            self.replace(note, nullifier)
        }
    }

    pub fn get_note(self, nullifier: Field) -> NoteEmission<Note> {
        let (retrieved_note, note_hash_for_read_request) =
            get_note(self.context, self.storage_slot);

        // Nullify current note to make sure it's reading the latest note.
        self.destroy_note_unsafe_shared(retrieved_note, note_hash_for_read_request, nullifier);

        // Add the same note again.
        // Because a nonce is added to every note in the kernel, its nullifier will be different.
        create_note(self.context, self.storage_slot, retrieved_note.note)
    }

    pub fn get_note_hash(self) -> Field {
        let (_, note_hash_for_read_request): (RetrievedNote<Note>, Field) =
            get_note(self.context, self.storage_slot);
        note_hash_for_read_request
    }

    pub fn destroy_note_unsafe_shared(
        self,
        retrieved_note: RetrievedNote<Note>,
        note_hash_for_read_request: Field,
        nullifier: Field,
    ) {
        let note_hash_for_nullify = compute_note_hash_for_nullify_from_read_request(
            retrieved_note,
            note_hash_for_read_request,
        );
        let note_hash = if retrieved_note.metadata.is_settled() {
            // Counter is zero, so we're nullifying a settled note and we don't populate the note_hash with real value.
            0
        } else {
            // A non-zero note hash counter implies that we're nullifying a pending note (i.e. one that has not yet been
            // persisted in the trees and is instead in the pending new note hashes array). In such a case we populate its
            // hash with real value to inform the kernel which note we're nullifying so that it can either squash both
            // the note and the nullifier if it's an inner note hash, or check that the it matches a pending note if it's
            // a siloed note hash.
            note_hash_for_nullify
        };

        self.context.push_nullifier_for_note_hash(nullifier, note_hash)
    }
}

impl<Note, let N: u32> PrivateSharedMutable<Note, UnconstrainedContext>
where
    Note: NoteType + NoteHash + Packable<N>,
{
    pub unconstrained fn is_initialized(self) -> bool {
        let nullifier = self.compute_initialization_nullifier();
        check_nullifier_exists(nullifier)
    }

    pub unconstrained fn view_note(self) -> Note {
        let mut options = NoteViewerOptions::new();
        view_notes(self.storage_slot, options.set_limit(1)).get(0)
    }
}
