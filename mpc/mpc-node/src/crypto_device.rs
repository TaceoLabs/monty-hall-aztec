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
        let sk = derive_secret_keys_from_seed("node1");
        let pk = sk.public_key();
        let key = pk.to_bytes();
        std::fs::write("node1.pk", key);

        let sk = derive_secret_keys_from_seed("node2");
        let pk = sk.public_key();
        let key = pk.to_bytes();
        std::fs::write("node2.pk", key);

        let sk = derive_secret_keys_from_seed("node3");
        let pk = sk.public_key();
        let key = pk.to_bytes();
        std::fs::write("node3.pk", key);

        //let sk = derive_secret_keys_from_seed(config.key_phrase.expose_secret());
        //let pk = sk.public_key();
        //let key = pk.to_bytes();
        //std::fs::write("node1", key);
        Self { sk }
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
