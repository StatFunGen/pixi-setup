#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

safe_expose_remove() {
    environment=$1
    executable=$2
    if [ -d ${PIXI_HOME}/envs/${environment} ]; then
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
    if [ ! -d ${PIXI_HOME}/envs ]; then
        mkdir -p ${PIXI_HOME}/envs
        existing_pkgs=""
    else
        existing_pkgs=$(ls ${PIXI_HOME}/envs 2>/dev/null | sort -u || echo "")
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
    if [ ! -d ${PIXI_HOME}/envs/${environment} ]; then
        missing_pkgs=$(cat ${package_list})
    else
        missing_pkgs=$(comm -13 <(pixi global list --environment ${environment} | cut -f 1 -d ' ' | head -n -6 | tail -n +3 | sort -u) <(sort -u ${package_list}))
    fi

    if (( $(echo ${missing_pkgs} | wc -w) > 0 )); then
        pixi global install --environment ${environment} $(echo ${missing_pkgs} | tr '\n' ' ')
    fi
}

export -f inject_packages

extract_section() {
    local file=$1 section=$2
    awk "/^# \[${section}\]/{found=1; next} /^# \[/{found=0} found && !/^#/ && NF" "$file"
}

export -f extract_section

# --- Prompt: installation path ---
_default_pixi_home="${HOME}/.pixi"
echo ""
echo "Where should pixi store its environments and packages?"
echo "  Default: ${_default_pixi_home}"
echo "  NOTE: Home directories often have storage quotas on HPC systems."
echo "  Consider a path on a larger filesystem, e.g. /lab/yourlab/.pixi"
echo ""
read -r -p "Installation path [${_default_pixi_home}]: " _user_pixi_home
export PIXI_HOME="${_user_pixi_home:-${_default_pixi_home}}"
echo "Using PIXI_HOME=${PIXI_HOME}"

# --- Prompt: install type ---
echo ""
echo "Choose installation type:"
echo "  1) minimal - Essential CLI tools + Python data science + base R"
echo "               ~5 GB, ~120k files"
echo "  2) full    - Complete bioinformatics environment (samtools, GATK, plink,"
echo "               STAR, Seurat, bioconductor packages, etc.)"
echo "               ~35 GB, ~350k files"
echo ""
read -r -p "Install type [1=minimal, 2=full, default=1]: " _install_type_input
case "${_install_type_input:-1}" in
    2|full)    INSTALL_TYPE="full" ;;
    *)         INSTALL_TYPE="minimal" ;;
esac
echo "Installation type: ${INSTALL_TYPE}"

# Ensure PIXI_HOME exists
mkdir -p "${PIXI_HOME}"

# Install pixi and source it right after installation to move forward
curl -fsSL https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/pixi-install.sh | bash
export PATH="${PIXI_HOME}/bin:${PATH}"

if [[ "${INSTALL_TYPE}" == "minimal" ]]; then
    # --- Minimal install ---
    _minimal_url="https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/envs/minimal_packages.txt"
    _minimal_file=$(mktemp)
    curl -fsSL "${_minimal_url}" -o "${_minimal_file}"

    install_global_packages <(extract_section "${_minimal_file}" "global")
    install_global_packages <(echo "coreutils")

    echo "Installing minimal R packages ..."
    inject_packages r-base <(extract_section "${_minimal_file}" "r")

    echo "Installing minimal Python packages ..."
    inject_packages python <(extract_section "${_minimal_file}" "python")

    rm -f "${_minimal_file}"
    pixi clean cache -y

    # Install config files (init.sh handles missing bioconductor packages gracefully)
    curl -fsSL https://raw.githubusercontent.com/StatFunGen/pixi-setup/main/init.sh | bash

else
    # --- Full install ---
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
fi

# print messages
BB='\033[1;34m'
NC='\033[0m'
echo -e "${BB}Installation completed. Pixi is installed at: ${PIXI_HOME}${NC}"
echo -e "${BB}Note: From now on you can install other R packages as needed with 'pixi global install --environment r-base ...'${NC}"
echo -e "${BB}and Python with 'pixi global install --environment python ...'${NC}"
