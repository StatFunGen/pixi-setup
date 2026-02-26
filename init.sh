#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Use PIXI_HOME if set (e.g. custom HPC path), otherwise fall back to default
PIXI_HOME="${PIXI_HOME:-${HOME}/.pixi}"

# Use Rprofile.site so that only pixi-installed R can see r-base packages
mkdir -p ${PIXI_HOME}/envs/python/lib/R/etc
echo ".libPaths('${PIXI_HOME}/envs/r-base/lib/R/library')" > ${PIXI_HOME}/envs/python/lib/R/etc/Rprofile.site

# Create config files for rstudio
mkdir -p ${HOME}/.config/rstudio
tee ${HOME}/.config/rstudio/database.conf << EOF
directory=${HOME}/.local/var/lib/rstudio-server
EOF

tee ${HOME}/.config/rstudio/rserver.conf << EOF
rsession-which-r=${PIXI_HOME}/envs/r-base/bin/R
auth-none=1
database-config-file=${HOME}/.config/rstudio/database.conf
server-daemonize=0
server-data-dir=${HOME}/.local/var/run/rstudio-server
server-user=${USER}
EOF

# Register Jupyter kernels
find ${PIXI_HOME}/envs/python/share/jupyter/kernels/ -maxdepth 1 -mindepth 1 -type d | \
    xargs -I % jupyter-kernelspec install --log-level=50 --user %
find ${PIXI_HOME}/envs/r-base/share/jupyter/kernels/ -maxdepth 1 -mindepth 1 -type d | \
    xargs -I % jupyter-kernelspec install --log-level=50 --user %
# ark --install

# Jupyter configurations
mkdir -p $HOME/.jupyter && \
curl -s -o $HOME/.jupyter/jupyter_lab_config.py https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/configs/jupyter/jupyter_lab_config.py && \
curl -s -o $HOME/.jupyter/jupyter_server_config.py https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/configs/jupyter/jupyter_server_config.py

mkdir -p ${HOME}/.config/code-server
curl -s -o $HOME/.config/code-server/config.yaml https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/configs/vscode/config.yaml
mkdir -p ${HOME}/.local/share/code-server/User
curl -s -o $HOME/.local/share/code-server/User/settings.json https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/configs/vscode/settings.json

if ! command -v code-server &> /dev/null; then
   echo "WARNING: code-server is not installed."
else
   code-server --install-extension ms-python.python
   code-server --install-extension ms-toolsai.jupyter
   code-server --install-extension reditorsupport.r
   code-server --install-extension rdebugger.r-debugger
   code-server --install-extension ionutvmi.path-autocomplete
   code-server --install-extension usernamehw.errorlens
fi

# Temporary fix to run post-link scripts (only present in full install with bioconductor packages)
if [ -f "${PIXI_HOME}/envs/r-base/bin/.bioconductor-genomeinfodbdata-post-link.sh" ]; then
    bash -c "PREFIX=${PIXI_HOME}/envs/r-base PATH=${PIXI_HOME}/envs/r-base/bin:${PATH} .bioconductor-genomeinfodbdata-post-link.sh"
fi
find ${PIXI_HOME}/envs/r-base/bin -name '*bioconductor-*-post-link.sh' | \
xargs -I % bash -c "PREFIX=${PIXI_HOME}/envs/r-base PATH=${PIXI_HOME}/envs/r-base/bin:${PATH} %"
