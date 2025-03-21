#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Determine the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  CONFIG_FILE="${HOME}/.zshrc"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux
  CONFIG_FILE="${HOME}/.bashrc"
else
  echo "Unsupported OS. Please use macOS or Linux."
  exit 1
fi

echo "Configuration file ${CONFIG_FILE} will be modified by this script."
touch ${CONFIG_FILE}

# Install pixi
if ! which pixi > /dev/null 2>&1
then
    # Install Pixi
    curl -fsSL https://pixi.sh/install.sh | bash
else
    echo "pixi is already installed."
fi

# Configure shell
if ! grep -q 'export PATH=${HOME}/.pixi/bin:${PATH}' "${CONFIG_FILE}"; then
    echo 'export PATH=${HOME}/.pixi/bin:${PATH}' >> "${CONFIG_FILE}"
fi
if ! grep -q 'unset PYTHONPATH' "${CONFIG_FILE}"; then
  echo "unset PYTHONPATH" >> "${CONFIG_FILE}"
fi
if ! grep -q 'export PYDEVD_DISABLE_FILE_VALIDATION=1' "${CONFIG_FILE}"; then
  echo "export PYDEVD_DISABLE_FILE_VALIDATION=1" >> "${CONFIG_FILE}"
fi

# set default channels
mkdir -p ${HOME}/.pixi && echo 'default_channels = ["dnachun", "conda-forge", "bioconda"]' > ${HOME}/.pixi/config.toml
