export CARGO_TERM_QUIET=true
BARRETENBERG_BINARY=~/.bb/bb  ##specify the $BARRETENBERG_BINARY path here

NARGO_VERSION=1.0.0-beta.3 ##specify the desired nargo version here
BARRETENBERG_VERSION=0.72.1 ##specify the desired barretenberg version here or use the corresponding one for this nargo version

CONOIR_PATH="/home/rwalch/Work/Taceo/product_dev/collaborative-circom"
PLAINDRIVER="${CONOIR_PATH}/target/release/plaindriver"
CRS_PATH="${CONOIR_PATH}/co-noir/co-noir/examples/test_vectors"
exit_code=0

REMOVE_OUTPUT=0
PIPE=""
if [[ $REMOVE_OUTPUT -eq 1 ]];
then
    PIPE=" > /dev/null 2>&1"
fi

# build the plaindriver binary
cwd=$(pwd)
cd $CONOIR_PATH
cargo build --release --bin plaindriver
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

test_cases=("monty_hall_test")

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
  echo "computing witnesses with nargo"
  bash -c "(cd ./${f} && nargo execute) $PIPE"

  # -e to exit on first error
  bash -c "${PLAINDRIVER} --prover-crs ${CRS_PATH}/bn254_g1.dat --verifier-crs ${CRS_PATH}/bn254_g2.dat --input ./${f}/Prover.toml --circuit ./${f}/target/${f}.json --hasher POSEIDON --out-dir ./${f} $PIPE" || failed=1

  if [ "$failed" -ne 0 ]
  then
    exit_code=1
    echo "::error::" $f "failed"
  fi
  run_proof_verification "$f" "poseidon"

  # Run with ZK:
  bash -c "${PLAINDRIVER} --prover-crs ${CRS_PATH}/bn254_g1.dat --verifier-crs ${CRS_PATH}/bn254_g2.dat --input ./${f}/Prover.toml --circuit ./${f}/target/${f}.json --hasher POSEIDON --out-dir ./${f} --zk $PIPE" || failed=1

  if [ "$failed" -ne 0 ]
  then
    exit_code=1
    echo "::error::" $f "failed with ZK"
  fi
  bash cleanup.sh

   # -e to exit on first error
  bash -c "${PLAINDRIVER} --prover-crs ${CRS_PATH}/bn254_g1.dat --verifier-crs ${CRS_PATH}/bn254_g2.dat --input ./${f}/Prover.toml --circuit ./${f}/target/${f}.json --hasher KECCAK --out-dir ./${f} $PIPE"  || failed=1

  if [ "$failed" -ne 0 ]
  then
    exit_code=1
    echo "::error::" $f "failed"
  fi
  run_proof_verification "$f" "keccak"
  # Run with ZK:
  bash -c "${PLAINDRIVER} --prover-crs ${CRS_PATH}/bn254_g1.dat --verifier-crs ${CRS_PATH}/bn254_g2.dat --input ./${f}/Prover.toml --circuit ./${f}/target/${f}.json --hasher KECCAK --out-dir ./${f} --zk $PIPE" || failed=1

  if [ "$failed" -ne 0 ]
  then
    exit_code=1
    echo "::error::" $f "failed with ZK"
  fi
  bash cleanup.sh
  echo ""
done

exit "$exit_code"
