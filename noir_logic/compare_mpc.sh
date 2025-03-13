export CARGO_TERM_QUIET=true
export RAYON_NUM_THREADS=$(($(nproc --all)/3)) # Limit the number of threads to prevent parties stealing from each other
BARRETENBERG_BINARY=~/.bb/bb  ##specify the $BARRETENBERG_BINARY path here

NARGO_VERSION=1.0.0-beta.3 ##specify the desired nargo version here
BARRETENBERG_VERSION=0.72.1 ##specify the desired barretenberg version here or use the corresponding one for this nargo version

CONOIR_PATH="/home/rwalch/Work/Taceo/product_dev/collaborative-circom"
CO_NOIR="${CONOIR_PATH}/target/release/co-noir"
CRS_PATH="${CONOIR_PATH}/co-noir/co-noir/examples/test_vectors"
CONFIG_PATH="./network/configs"
exit_code=0

REMOVE_OUTPUT=0
PIPE=""
if [[ $REMOVE_OUTPUT -eq 1 ]];
then
    PIPE=" > /dev/null 2>&1"
fi

# build the co-noir binary
cwd=$(pwd)
cd $CONOIR_PATH
cargo build --release --bin co-noir
cd ${cwd}

## install noirup: curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
r=$(bash -c "nargo --version")
if  [[ $r != "nargo version = $NARGO_VERSION"* ]];
then
    bash -c "noirup -v ${NARGO_VERSION}"
fi

## use one of these two methods
## install bbup: curl -L bbup.dev | bash
# bash -c "bbup -nv 0.${NARGO_VERSION}.0"
r=$(bash -c "$BARRETENBERG_BINARY --version 2> /dev/null")
if  [[ $r != "$BARRETENBERG_VERSION" ]];
then
    bash -c "bbup -v ${BARRETENBERG_VERSION}"
fi

echo "Using nargo version $NARGO_VERSION"
echo "Using bb version $BARRETENBERG_VERSION"
echo ""

test_cases=("monty_hall_test" "monty_hall_choose" "monty_hall_switch" "monty_hall_init")

run_proof_verification() {
  local name=$1
  local algorithm=$2

  if [[ "$algorithm" == "poseidon" ]]; then
    proof_file="proof.bb${BARRETENBERG_VERSION}.poseidon"
    vk_file="vk.bb${BARRETENBERG_VERSION}.poseidon"
    prove_command="prove_ultra_honk"
    write_command="write_vk_ultra_honk"
    verify_command="verify_ultra_honk"
  else
    proof_file="proof.bb${BARRETENBERG_VERSION}.keccak"
    vk_file="vk.bb${BARRETENBERG_VERSION}.keccak"
    prove_command="prove_ultra_keccak_honk"
    write_command="write_vk_ultra_keccak_honk"
    verify_command="verify_ultra_keccak_honk"
  fi

  echo "comparing" $name "with bb and $algorithm transcript"

  bash -c "$BARRETENBERG_BINARY $prove_command -b ./${name}/target/${name}.json -w ./${name}/target/${name}.gz -o ./${name}/${proof_file} > /dev/null 2>&1"

  diff ./${name}/${proof_file} ./${name}/proof
  if [[ $? -ne 0 ]]; then
    exit_code=1
    echo "::error::$name diff check of proofs failed"
  fi

  out=$(bash -c "$BARRETENBERG_BINARY $write_command -b ./${name}/target/${name}.json -o ./${name}/${vk_file} 2>&1")
  out="${out%[*}"
  echo $out


  bash -c "$BARRETENBERG_BINARY $verify_command -p ./${name}/proof -k ./${name}/vk > /dev/null 2>&1"
  if [[ $? -ne 0 ]]; then
    exit_code=1
    echo "::error::$name verifying with bb, our proof and our key failed"
  fi

  bash -c "$BARRETENBERG_BINARY $verify_command -p ./${name}/proof -k ./${name}/${vk_file} > /dev/null 2>&1"
  if [[ $? -ne 0 ]]; then
    exit_code=1
    echo "::error::$name verifying with bb, our proof and their key failed"
  fi

  bash -c "$BARRETENBERG_BINARY $verify_command -p ./${name}/${proof_file} -k ./${name}/vk > /dev/null 2>&1"
  if [[ $? -ne 0 ]]; then
    exit_code=1
    echo "::error::$name verifying with bb, their proof and our key failed"
  fi

  bash -c "$BARRETENBERG_BINARY $verify_command -p ./${name}/${proof_file} -k ./${name}/${vk_file} > /dev/null 2>&1"
  if [[ $? -ne 0 ]]; then
    exit_code=1
    echo "::error::$name verifying with bb, their proof and their key failed"
  fi
  return $exit_code
}

# comparing works with all test scripts where "run_full_" is followed by the precise test case name
for f in "${test_cases[@]}"; do
  echo "running ultrahonk example" $f

  failed=0

  # compile witnesses and bytecode with specified nargo version
  echo "compiling circuits with nargo"
  bash -c "(cd ./${f} && nargo execute) $PIPE"

  echo "computing witnesses, proofs and verification with co-noir"
  # -e to exit on first error
  # split input into shares
  bash -c "${CO_NOIR} split-input --circuit ./${f}/target/${f}.json --input ./${f}/Prover.toml --protocol REP3 --out-dir ./${f} $PIPE"  || failed=1
  # run witness extension in MPC
  bash -c "${CO_NOIR} generate-witness --input ./${f}/Prover.toml.0.shared --circuit ./${f}/target/${f}.json --protocol REP3 --config ${CONFIG_PATH}/party1.toml --out ./${f}/${f}.gz.0.shared $PIPE"  || failed=1 &
  bash -c "${CO_NOIR} generate-witness --input ./${f}/Prover.toml.1.shared --circuit ./${f}/target/${f}.json --protocol REP3 --config ${CONFIG_PATH}/party2.toml --out ./${f}/${f}.gz.1.shared $PIPE"  || failed=1 &
  bash -c "${CO_NOIR} generate-witness --input ./${f}/Prover.toml.2.shared --circuit ./${f}/target/${f}.json --protocol REP3 --config ${CONFIG_PATH}/party3.toml --out ./${f}/${f}.gz.2.shared $PIPE"  || failed=1 &
   wait $(jobs -p)
  # run proving in MPC
  bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.0.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher POSEIDON --config ${CONFIG_PATH}/party1.toml --out ./${f}/proof --public-input public_input.json $PIPE"  || failed=1&
  bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.1.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher POSEIDON --config ${CONFIG_PATH}/party2.toml --out ./${f}/proof.1.proof  $PIPE"  || failed=1&
  bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.2.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher POSEIDON --config ${CONFIG_PATH}/party3.toml --out ./${f}/proof.2.proof $PIPE"  || failed=1
  wait $(jobs -p)
  # Create verification key
  bash -c "${CO_NOIR} create-vk --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --hasher POSEIDON --vk ./${f}/vk $PIPE"  || failed=1
  # verify proof
  bash -c "${CO_NOIR} verify --proof ./${f}/proof --vk ./${f}/vk --hasher POSEIDON --crs ${CRS_PATH}/bn254_g2.dat$PIPE"  || failed=1

  echo "proving and verifying with ZK in co-noir  and poseidon transcript"
  # run proving in MPC with ZK
#   bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.0.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher POSEIDON --config ${CONFIG_PATH}/party1.toml --out ./${f}/zk_proof --public-input public_input.json --zk $PIPE"  || failed=1&
#   bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.1.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher POSEIDON --config ${CONFIG_PATH}/party2.toml --out ./${f}/zk_proof.1.proof --zk $PIPE"  || failed=1&
#   bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.2.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher POSEIDON --config ${CONFIG_PATH}/party3.toml --out ./${f}/zk_proof.2.proof --zk $PIPE"  || failed=1
#   wait $(jobs -p)
#   # verify proof
#   bash -c "${CO_NOIR} verify --proof ./${f}/zk_proof --vk ./${f}/vk --hasher POSEIDON --crs ${CRS_PATH}/bn254_g2.dat --has-zk $PIPE"  || failed=1

  # if [ "$failed" -ne 0 ]
  # then
  #   exit_code=1
  #   echo "::error::" $f "failed"
  # fi
  run_proof_verification "$f" "poseidon"
  bash cleanup.sh

#   # split input into shares
#   bash -c "${CO_NOIR} split-input --circuit ./${f}/target/${f}.json --input ./${f}/Prover.toml --protocol REP3 --out-dir ./${f} $PIPE"  || failed=1
#   # run witness extension in MPC
#   bash -c "${CO_NOIR} generate-witness --input ./${f}/Prover.toml.0.shared --circuit ./${f}/target/${f}.json --protocol REP3 --config ${CONFIG_PATH}/party1.toml --out ./${f}/${f}.gz.0.shared $PIPE"  || failed=1&
#   bash -c "${CO_NOIR} generate-witness --input ./${f}/Prover.toml.1.shared --circuit ./${f}/target/${f}.json --protocol REP3 --config ${CONFIG_PATH}/party2.toml --out ./${f}/${f}.gz.1.shared $PIPE"  || failed=1&
#   bash -c "${CO_NOIR} generate-witness --input ./${f}/Prover.toml.2.shared --circuit ./${f}/target/${f}.json --protocol REP3 --config ${CONFIG_PATH}/party3.toml --out ./${f}/${f}.gz.2.shared $PIPE"  || failed=1
#   wait $(jobs -p)
#   # run proving in MPC
#   bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.0.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher KECCAK --config ${CONFIG_PATH}/party1.toml --out ./${f}/proof --public-input public_input.json $PIPE"  || failed=1&
#   bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.1.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher KECCAK --config ${CONFIG_PATH}/party2.toml --out ./${f}/proof.1.proof  $PIPE"  || failed=1&
#   bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.2.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher KECCAK --config ${CONFIG_PATH}/party3.toml --out ./${f}/proof.2.proof $PIPE"  || failed=1
#   wait $(jobs -p)
#   # Create verification key
#   bash -c "${CO_NOIR} create-vk --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --hasher KECCAK --vk ./${f}/vk $PIPE"  || failed=1
#   # verify proof
#   bash -c "${CO_NOIR} verify --proof ./${f}/proof --vk ./${f}/vk --hasher KECCAK --crs ${CRS_PATH}/bn254_g2.dat $PIPE"  || failed=1

#   echo "proving and verifying with ZK in co-noir and keccak transcript"
#   # run proving in MPC with ZK
#   bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.0.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher KECCAK --config ${CONFIG_PATH}/party1.toml --out ./${f}/zk_proof --public-input public_input.json --zk $PIPE"  || failed=1&
#   bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.1.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher KECCAK --config ${CONFIG_PATH}/party2.toml --out ./${f}/zk_proof.1.proof --zk $PIPE"  || failed=1&
#   bash -c "${CO_NOIR} build-and-generate-proof --witness ./${f}/${f}.gz.2.shared --circuit ./${f}/target/${f}.json --crs ${CRS_PATH}/bn254_g1.dat --protocol REP3 --hasher KECCAK --config ${CONFIG_PATH}/party3.toml --out ./${f}/zk_proof.2.proof --zk $PIPE"  || failed=1
#   wait $(jobs -p)
#   # verify proof
#   bash -c "${CO_NOIR} verify --proof ./${f}/zk_proof --vk ./${f}/vk --hasher KECCAK --crs ${CRS_PATH}/bn254_g2.dat --has-zk $PIPE"  || failed=1

#   # if [ "$failed" -ne 0 ]
#   # then
#   #   exit_code=1
#   #   echo "::error::" $f "failed"
#   # fi
#   run_proof_verification "$f" "keccak"
#   bash cleanup.sh
#   echo ""
done

exit "$exit_code"
