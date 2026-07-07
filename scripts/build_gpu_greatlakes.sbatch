#!/bin/bash
# =====================================================================
# Build OpenDiS + ExaDiS (CUDA / V100) on UMich Great Lakes and install
# the python bindings into the 'mace' conda environment.
#
# Submit with:   sbatch scripts/build_gpu_greatlakes.sbatch
# Watch log:     tail -f build_<jobid>.log
# =====================================================================
#SBATCH --job-name=opendis-gpu-build
#SBATCH --account=tswin0
#SBATCH --partition=gpu
#SBATCH --gres=gpu:v100:1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=build_%j.log

set -euo pipefail

# --- repository root (directory that contains this scripts/ folder) --------
OPENDIS_ROOT="/gpfs/accounts/tswin_root/tswin0/tswin/REPREDINE/OpenDis.git"
cd "$OPENDIS_ROOT"

echo "==> Host: $(hostname)   Job: ${SLURM_JOB_ID:-interactive}"
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader || true

# --- toolchain: gcc 13 + CUDA 12.8 -----------------------------------------
# gcc 13 (not 14): pybind11 2.11 -- pinned by the exadis fork -- fails to
# compile its py::enum_ helper under GCC 14 (ambiguous 'factory' template).
# gcc 13 builds it cleanly and stays ABI-safe with the mace env's conda
# libstdc++ (GLIBCXX_3.4.34, newer than what a gcc-13 build requires).
module purge
module load gcc/13.2.0 cuda/12.8.2 cmake/3.26.3
echo "==> $(gcc --version | head -1)"
echo "==> $(nvcc --version | grep release)"
echo "==> $(cmake --version | head -1)"

# Make the mace env python the one seen during the build (topology codegen,
# pybind11 discovery). PYTHON_EXECUTABLE in the sys.cmake also points here.
export PATH="$HOME/.conda/envs/mace/bin:$PATH"

# --- make sure all submodules are present (exadis fork + kokkos + pybind11) -
git submodule update --init --recursive

# --- configure a fresh out-of-source build ---------------------------------
rm -rf build
cmake -S . -B build \
      -DSYS=greatlakes_gpu \
      -DCMAKE_BUILD_TYPE=Release

# --- compile + install (into ./install and in-tree pyexadis .so) -----------
cmake --build build -j "${SLURM_CPUS_PER_TASK:-8}"
cmake --build build --target install

# --- register the source tree in the mace environment ----------------------
# OpenDiS runs from the source tree via PYTHONPATH; drop a .pth into the mace
# site-packages so `import pyexadis`, `import pydis` and the framework work
# from anywhere while the mace env is active.
bash "$OPENDIS_ROOT/scripts/install_into_mace.sh"

# --- smoke test on the allocated V100 --------------------------------------
echo "==> Import smoke test on $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
# conda's activate.d scripts (e.g. MKL) reference unbound vars; relax 'set -u'
# just around activation so it doesn't abort the job.
set +u
source /sw/pkgs/arc/mamba/py3.12/etc/profile.d/conda.sh
conda activate mace
set -u
python - <<'PY'
import pyexadis
print("pyexadis OK ->", pyexadis.__file__)
import pydis
print("pydis    OK ->", pydis.__file__)
PY

echo "==> Build + install complete."
