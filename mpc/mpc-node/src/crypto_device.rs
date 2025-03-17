use secrecy::ExposeSecret;

use crate::config::NodeConfig;

pub struct CryptoDevice {
    sk: crypto_box::SecretKey,
}

impl CryptoDevice {
    pub(crate) fn init(config: &NodeConfig) -> Self {
        if rustls::crypto::aws_lc_rs::default_provider()
            .install_default()
            .is_err()
        {
            tracing::warn!("cannot install rustls crypto provider!");
            tracing::warn!("we continue but this should not happen...");
        };

        Self {
            sk: derive_secret_keys_from_seed(config.key_phrase.expose_secret()),
        }
    }
}

pub fn derive_secret_keys_from_seed(seed: &str) -> crypto_box::SecretKey {
    let salt = b"csn_kdf_salt_v1";
    let enc_key_info = b"csn_crypto_box_encryption_key";
    let kdf = hkdf::Hkdf::<sha2::Sha256>::new(Some(&salt[..]), seed.as_bytes());
    let mut secret_key1 = [0u8; crypto_box::KEY_SIZE];
    kdf.expand(&enc_key_info[..], &mut secret_key1)
        .expect("Failed to expand encryption key");
    crypto_box::SecretKey::from_bytes(secret_key1)
}
