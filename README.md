# Hybrid ANN/SNN Processing Element

This repo contains code and infrastructure to benchmark our hybrid ANN/SNN Accelerator PE.

## Dependencies
### Submodules
The repo contains several git submodule dependencies and should be cloned recursively:
```bash
git clone --recursive https://github.com/eliahreeves/snn-ann-pe
```
### Other Dependencies
This project uses nix for all dependencies. You can install everything manually, but using nix will save a lot of time especially for LibreLane. Nix is available on all Unix-like operating systems. Download nix [here](https://nixos.org/download/). Flakes must be enabled.

Refer to [flake.nix](./flake.nix) if you wish to install manually.

## Running
### RTL
Refer to the [Makefile](./Makefile) for targets. The TOP parameter can be used to change the stimuli run, but it may also be required to modify [rtl.f](./rtl/rtl.f) and [dv.f](./dv/dv.f). Due to time constraints the test benches are only for stimuli and do not verify the design. Some verification was done using Icarus simulator, but that test bench is not present. Adding more testing would be a crucial step for final results.

### Flow
PPA metric were collected using the librelane flow. Config is available at [layout/](./layout). To run you must activate the nix shell in the librelane submodule then invoke from the same directory as the JSON file. It is critical that `synth/build/rtl.sv2v.v` has been generated.
