use super::field::sqrt;
use std::embedded_curve_ops::{
    EmbeddedCurvePoint, EmbeddedCurveScalar, fixed_base_scalar_mul, multi_scalar_mul,
};

pub fn derive_shared_secret_sender(rand: Field, rcp_address: Field) -> (Field, EmbeddedCurvePoint) {
    let (eph_sk, eph_pk) = generate_ephemeral_key_pair(rand);
    let shared_secret = derive_ecdh_shared_secret_using_aztec_address(eph_sk, rcp_address);
    (shared_secret.x, eph_pk)
}

pub fn derive_shared_secret_receiver(
    rcp_secret: EmbeddedCurveScalar,
    ephemeral_pub: EmbeddedCurvePoint,
) -> Field {
    let shared_secret = derive_ecdh_shared_secret(rcp_secret, ephemeral_pub);
    shared_secret.x
}

global TWO_POW_128: Field = 0x100000000000000000000000000000000;
global TWO_POW_64: Field = 0x10000000000000000;
global MAX_FIELD_VALUE: Field =
    21888242871839275222246405745257275088548364400416034343698204186575808495616;

// Decomposes a single field into two 16 byte fields.
// From [https://github.com/noir-lang/noir/blob/master/noir_stdlib/src/field/bn254.nr](https://github.com/noir-lang/noir/blob/master/noir_stdlib/src/field/bn254.nr)
fn compute_decomposition(mut x: Field) -> (Field, Field) {
    // Here's we're taking advantage of truncating 64 bit limbs from the input field
    // and then subtracting them from the input such the field division is equivalent to integer division.
    let low_lower_64 = (x as u64) as Field;
    x = (x - low_lower_64) / TWO_POW_64;
    let low_upper_64 = (x as u64) as Field;

    let high = (x - low_upper_64) / TWO_POW_64;
    let low = low_upper_64 * TWO_POW_64 + low_lower_64;

    (low, high)
}

unconstrained fn decompose_hint(x: Field) -> (Field, Field) {
    compute_decomposition(x)
}

// from [https://github.com/noir-lang/noir/blob/master/noir_stdlib/src/hash/mod.nr](https://github.com/noir-lang/noir/blob/master/noir_stdlib/src/hash/mod.nr)
#[field(bn254)]
// Same as from_field but:
// does not assert the limbs are 128 bits
// does not assert the decomposition does not overflow the EmbeddedCurveScalar
fn from_field_unsafe(scalar: Field) -> EmbeddedCurveScalar {
    // Safety: xlo and xhi decomposition is checked below
    let (xlo, xhi) = unsafe { decompose_hint(scalar) };
    // Check that the decomposition is correct
    assert_eq(scalar, xlo + TWO_POW_128 * xhi);
    EmbeddedCurveScalar { lo: xlo, hi: xhi }
}

// From [https://github.com/AztecProtocol/aztec-packages/blob/e45271fb4ce98c1c6edc2a416dbaa354cce1df88/noir-projects/aztec-nr/aztec/src/keys/ephemeral.nr](https://github.com/AztecProtocol/aztec-packages/blob/e45271fb4ce98c1c6edc2a416dbaa354cce1df88/noir-projects/aztec-nr/aztec/src/keys/ephemeral.nr)
pub(crate) fn generate_ephemeral_key_pair(
    rand: Field,
) -> (EmbeddedCurveScalar, EmbeddedCurvePoint) {
    // @todo Need to draw randomness from the full domain of Fq not only Fr
    // We use the randomness to preserve the privacy of both the sender and recipient via encryption, so a malicious
    // sender could use non-random values to reveal the plaintext. But they already know it themselves anyway, and so
    // the recipient already trusts them to not disclose this information. We can therefore assume that the sender will
    // cooperate in the random value generation.

    // We use the unsafe version of `fr_to_fq` because multi_scalar_mul (called by derive_public_key) will constrain
    // the scalars.
    let eph_sk = from_field_unsafe(rand);
    let eph_pk = fixed_base_scalar_mul(eph_sk);

    (eph_sk, eph_pk)
}

/// Computes a standard ecdh shared secret: [secret] * public_key = shared_secret.
/// The input secret is known only to one party. The output shared secret is derivable
/// by both parties, through this function.
/// E.g.:
/// Epk = esk * G // ephemeral keypair
/// Pk = sk * G // recipient keypair
/// Shared secret S = esk * Pk = sk * Epk // see how this function can be called with two different sets of inputs, depending on which secret the caller knows (either esk or sk)?
// See also: https://en.wikipedia.org/wiki/Elliptic-curve_Diffie%E2%80%93Hellman
// From [https://github.com/AztecProtocol/aztec-packages/blob/3b981f9217f9b859bdfbcdba2f5c080392c98da6/noir-projects/aztec-nr/aztec/src/keys/ecdh_shared_secret.nr](https://github.com/AztecProtocol/aztec-packages/blob/3b981f9217f9b859bdfbcdba2f5c080392c98da6/noir-projects/aztec-nr/aztec/src/keys/ecdh_shared_secret.nr)
fn derive_ecdh_shared_secret(
    secret: EmbeddedCurveScalar,
    public_key: EmbeddedCurvePoint,
) -> EmbeddedCurvePoint {
    let shared_secret = multi_scalar_mul([public_key], [secret]);
    shared_secret
}

/// Computes a standard ecdh shared secret using the address public key of the given address:
/// [ephemeral_secret] * recipient_address_public_key = shared_secret.
/// The intention is that the _creator_ of a shared secret would call this function,
/// given the address of their intended recipient.
// From [https://github.com/AztecProtocol/aztec-packages/blob/3b981f9217f9b859bdfbcdba2f5c080392c98da6/noir-projects/aztec-nr/aztec/src/keys/ecdh_shared_secret.nr](https://github.com/AztecProtocol/aztec-packages/blob/3b981f9217f9b859bdfbcdba2f5c080392c98da6/noir-projects/aztec-nr/aztec/src/keys/ecdh_shared_secret.nr)
fn derive_ecdh_shared_secret_using_aztec_address(
    ephemeral_secret: EmbeddedCurveScalar,
    recipient_address: Field,
) -> EmbeddedCurvePoint {
    derive_ecdh_shared_secret(ephemeral_secret, to_address_point(recipient_address))
}

// From [https://github.com/AztecProtocol/aztec-packages/blob/3b981f9217f9b859bdfbcdba2f5c080392c98da6/noir-projects/noir-protocol-circuits/crates/types/src/address/aztec_address.nr](https://github.com/AztecProtocol/aztec-packages/blob/3b981f9217f9b859bdfbcdba2f5c080392c98da6/noir-projects/noir-protocol-circuits/crates/types/src/address/aztec_address.nr)
fn to_address_point(address: Field) -> EmbeddedCurvePoint {
    // We compute the address point by taking our address, setting it to x, and then solving for y in the
    // equation which defines our bn curve:
    // y^2 = x^3 - 17; x = address
    let x = address;
    let y_squared = x * x * x - 17;

    // TODO (#8970): Handle cases where we cannot recover a point from an address
    let mut y = sqrt(y_squared).unwrap();

    // If we get a negative y coordinate (any y where y > MAX_FIELD_VALUE / 2), we pin it to the
    // positive one (any value where y <= MAX_FIELD_VALUE / 2) by subtracting it from the Field modulus
    // note: The field modulus is MAX_FIELD_VALUE + 1
    if (!(y.lt(MAX_FIELD_VALUE / 2) | y.eq(MAX_FIELD_VALUE / 2))) {
        y = (MAX_FIELD_VALUE + 1) - y;
    }
    EmbeddedCurvePoint { x: address, y, is_infinite: false }
}

#[test]
fn derive_secret() {
    let rand = 123;
    let rcp_sk = EmbeddedCurveScalar { lo: 0x1234, hi: 0x2345 };
    let mut rcp_pk = std::embedded_curve_ops::fixed_base_scalar_mul(rcp_sk);
    let rcp_address = rcp_pk.x;

    // We were lazy in deriving the secret key, and didn't check the resulting y-coordinate of the rcp_pk to be less than half the field modulus.
    // If needed, we negate the pk's so that they yield valid address points.
    // (We could also have negated the secrets, but there's no negate method for
    // EmbeddedCurvesScalar).
    rcp_pk = if (to_address_point(rcp_address) == rcp_pk) {
        rcp_pk
    } else {
        -rcp_pk
    };

    let (shared_secret, eph_pk) = derive_shared_secret_sender(rand, rcp_address);
    let shared_secret_rcp = derive_shared_secret_receiver(rcp_sk, eph_pk);
    assert(shared_secret == shared_secret_rcp);
}
