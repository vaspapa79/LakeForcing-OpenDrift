# LakeForcing -- reproducible container for the open, engine-independent portion
# of the pipeline: the sigma-to-z CF exporter and the OpenDrift transport
# demonstration. The Delft3D engine is installed separately and is NOT required;
# the default command runs the same clean-checkout fixture test as the CI.
#
#   docker build -t lakeforcing .
#   docker run --rm lakeforcing                    # exporter fixture test (as CI)
#   docker run --rm -it lakeforcing bash           # interactive session
#
# The environment is pinned via environment.yml (conda-forge; Python 3.11,
# opendrift==1.14.9), so the exporter + demo chain reproduces deterministically.
FROM condaforge/miniforge3:24.11.3-2

COPY environment.yml /tmp/environment.yml
RUN mamba env create -f /tmp/environment.yml && mamba clean -afy

ENV PATH=/opt/conda/envs/lakeforcing/bin:$PATH

WORKDIR /work
COPY . /work

CMD ["pytest", "tests/test_cf_export.py", "-q"]
