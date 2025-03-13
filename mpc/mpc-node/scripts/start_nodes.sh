cargo run --release --bin mpc-node -- --bind-addr 127.0.0.1:8000 --crs-path ../data/bn254_g1.dat & 
cargo run --release --bin mpc-node -- --bind-addr 127.0.0.1:8001 --crs-path ../data/bn254_g1.dat & 
cargo run --release --bin mpc-node -- --bind-addr 127.0.0.1:8002 --crs-path ../data/bn254_g1.dat
