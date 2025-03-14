use pss_utils::dh::derive_shared_secret_sender;
use std::embedded_curve_ops::EmbeddedCurvePoint;

fn main(rand: Field, address: Field) -> pub (Field, EmbeddedCurvePoint) {
    derive_shared_secret_sender(rand, address)
}
