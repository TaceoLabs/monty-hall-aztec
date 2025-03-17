use dep::aztec; //ouside of the contract block
use dep::aztec::macros::notes::custom_note;
use dep::aztec::note::note_interface::{NoteHash};
use dep::aztec::prelude::PrivateContext;
use dep::aztec::protocol_types::{
    traits::{Deserialize, Packable, Serialize}
};
use std::embedded_curve_ops::EmbeddedCurvePoint;

/// This note abstracts away the Private Shared State of an MPC-network.
/// Since the data in this Note is not known to anyone, only to the MPC-network as a collective group, it is only represented as a commitment on Aztec. The PXE of the party communicating with the smart contract also does not know about the data and is only aware of the commitment.
/// Thus, when constructing the note, the commitment has to be given to it. Furthermore, compute_note_hash() will just return this commitmetn.
/// This note might never be nullified by the Aztec infrastructure, so compute_nullifier() will panic. The Note can only be nullified by a nullifier computed by the MPC-network.
/// It is save to use this Note in a PrivateImmutable or PrivateSharedMutable, but not in a PrivateMutable due to this nullification issue.
#[custom_note]
#[derive(Eq, Serialize, Deserialize)]
pub struct TACEONote {
     nullifying_pk: EmbeddedCurvePoint,
     commitment: Field,
}

pub impl TACEONote {
    pub fn new(nullifying_pk: EmbeddedCurvePoint, commitment: Field) -> Self {
        TACEONote { nullifying_pk, commitment }
    }

    pub fn get_commitment(self) -> Field {
        self.commitment
    }
}


impl NoteHash for TACEONote {
    fn compute_note_hash(self, _storage_slot: Field) -> Field {
        self.commitment
    }

    fn compute_nullifier(
        self,
        _context: &mut PrivateContext,
        note_hash_for_nullify: Field,
    ) -> Field {
        assert(false);
        note_hash_for_nullify
}

    unconstrained fn compute_nullifier_unconstrained(self, note_hash_for_nullify: Field) -> Field {
        assert(false);
        note_hash_for_nullify
     }
}

impl Packable<4> for TACEONote {
    fn pack(self) -> [Field; 4] {
        [self.nullifying_pk.x, self.nullifying_pk.x, self.nullifying_pk.is_infinite as Field, self.commitment]
    }

    fn unpack(packed_content: [Field; 4]) -> TACEONote {
        packed_content[2].assert_max_bit_size::<1>();
        TACEONote::new(
            EmbeddedCurvePoint { x: packed_content[0], y: packed_content[1], is_infinite: packed_content[2] as bool },
            packed_content[1],


        )
    }
}
