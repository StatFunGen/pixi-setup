#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

safe_expose_remove() {
    environment=$1
    executable=$2
    if [ -d ${HOME}/.pixi/envs/${environment} ]; then
        exposed_exes=$(pixi global list --environment ${environment} | tail -n 3 | head -n 1 | tr ',' '\n')
        if [[ " ${exposed_exes[*]} " =~ [[:space:]]${executable}[[:space:]] ]]; then
            pixi global expose remove ${executable}
        fi
    fi
}

export -f safe_expose_remove

install_global_packages() {
    package_list=$1
    
    # Check if the directory exists, if not, create an empty list of packages
    if [ ! -d ${HOME}/.pixi/envs ]; then
        mkdir -p ${HOME}/.pixi/envs
        existing_pkgs=""
    else
        existing_pkgs=$(ls ${HOME}/.pixi/envs 2>/dev/null | sort -u || echo "")
    fi
    
    # Use the existing packages or empty string to compare with desired packages
    missing_pkgs=$(comm -13 <(echo "$existing_pkgs" | sort -u) <(sort -u ${package_list}))
    
    if (($(echo ${missing_pkgs} | wc -w) > 0 )); then
        pixi global install $(echo ${missing_pkgs} | tr '\n' ' ')
    fi
}

export -f install_global_packages

inject_packages() {
    environment=$1
    package_list=$2
    
    # Check if the environment exists before trying to list packages
    if [ ! -d ${HOME}/.pixi/envs/${environment} ]; then
        missing_pkgs=$(cat ${package_list})
    else
        missing_pkgs=$(comm -13 <(pixi global list --environment ${environment} | cut -f 1 -d ' ' | head -n -6 | tail -n +3 | sort -u) <(sort -u ${package_list}))
    fi
    
    if (( $(echo ${missing_pkgs} | wc -w) > 0 )); then
        pixi global install --environment ${environment} $(echo ${missing_pkgs} | tr '\n' ' ')
    fi
}

export -f inject_packages

# If PIXI_HOME is not set already, set it to ${HOME}/.pixi
if [[ -z ${PIXI_HOME:-} ]]; then
    export PIXI_HOME="${HOME}/.pixi"
fi

# Ensure PIXI_HOME exists
mkdir -p ${PIXI_HOME}

# Install pixi
curl -fsSL https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/pixi-install.sh | bash

if ! which pixi > /dev/null 2>&1
then
    BB='\033[1;34m'
    NC='\033[0m'
    echo -e "${BB}pixi installed. Please run 'source ${CONFIG_FILE}' to reload your configuration or restart your terminal, and rerun this setup script in order to complete the rest of the installation.${NC}"
    exit 1
fi

# Install global packages
install_global_packages <(curl -fsSL https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/envs/global_packages.txt | grep -v "#")

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    safe_expose_remove util-linux kill
fi

install_global_packages <(echo "coreutils")

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    safe_expose_remove coreutils kill
    safe_expose_remove coreutils uptime
    install_global_packages <(curl -fsSL https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/envs/global_packages_linux.txt | grep -v "#")
fi

echo "Installing recommended R libraries ..."
inject_packages r-base <(curl -fsSL https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/envs/r_packages.txt | grep -v "#")

echo "Installing recommended Python packages ..."
inject_packages python <(curl -fsSL https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/envs/python_packages.txt | grep -v "#")

pixi clean cache -y

# Install config files
curl -fsSL https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/init.sh | bash

# print messages
BB='\033[1;34m'
NC='\033[0m'
echo -e "${BB}Installation completed.${NC}"
echo -e "${BB}Note: From now on you can install other R packages as needed with 'pixi global install --environment r-base ...'${NC}"
echo -e "${BB}and Python with 'pixi global install --environment python ...'${NC}"
