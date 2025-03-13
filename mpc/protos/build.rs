fn main() {
    println!("cargo:rerun-if-changed=monty_hall.proto");
    println!("cargo:rerun-if-changed=build.rs");
    tonic_build::configure()
        .protoc_arg("--experimental_allow_proto3_optional")
        .out_dir("src/")
        .compile_protos(
            &["monty_hall.proto"], // Files in the path
            &["."],                // The path to search
        )
        .unwrap();
}
