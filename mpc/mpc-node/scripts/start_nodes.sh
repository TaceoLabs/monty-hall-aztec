cargo run --release --bin mpc-node -- --bind-addr 127.0.0.1:8000 --crs-path ../data/bn254_g1.dat --network-config ../data/configs/party1.toml & 
RUST_LOG="warn" cargo run --release --bin mpc-node -- --bind-addr 127.0.0.1:8001 --crs-path ../data/bn254_g1.dat --network-config ../data/configs/party2.toml & 
RUST_LOG="warn" cargo run --release --bin mpc-node -- --bind-addr 127.0.0.1:8002 --crs-path ../data/bn254_g1.dat --network-config ../data/configs/party3.toml
