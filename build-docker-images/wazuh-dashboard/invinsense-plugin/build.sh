#!/bin/bash

set -ex

# Script parameters
wazuh_branch="invinsense-4.0"
plugin_platform_branch="invinsense-4.0"
checksum="no"
app_revision=1

# Paths
plugin_platform_dir="/tmp/source"
source_dir="${plugin_platform_dir}/plugins/wazuh"
build_dir="${source_dir}/build"
destination_dir="/wazuh_app"
checksum_dir="/var/local/checksum"

# Repositories URLs
wazuh_app_clone_repo_url="https://github.com/Infopercept/invinsense-kibana-app.git"
#wazuh_app_clone_repo_url="https://github.com/wazuh/wazuh-kibana-app.git"
wazuh_app_raw_repo_url="https://raw.githubusercontent.com/Infopercept/invinsense-kibana-app"
#wazuh_app_raw_repo_url="https://raw.githubusercontent.com/wazuh/wazuh-kibana-app"
plugin_platform_app_repo_url="https://github.com/Infopercept/invinsense-dashboard.git"
#plugin_platform_app_repo_url="https://github.com/opensearch-project/OpenSearch-Dashboards.git"
plugin_platform_app_raw_repo_url="https://raw.githubusercontent.com/Infopercept/invinsense-dashboard"
#plugin_platform_app_raw_repo_url="https://raw.githubusercontent.com/opensearch-project/OpenSearch-Dashboards"
wazuh_app_package_json_url="${wazuh_app_raw_repo_url}/${wazuh_branch}/package.json"

# Script vars
wazuh_version=""
plugin_platform_version=""
plugin_platform_yarn_version=""
plugin_platform_node_version=""


change_node_version () {
    installed_node_version="$(node -v)"
    node_version=$1

    n ${node_version}

    if [[ "${installed_node_version}" != "v${node_version}" ]]; then
        mv /usr/local/bin/node /usr/bin
        mv /usr/local/bin/npm /usr/bin
        mv /usr/local/bin/npx /usr/bin
    fi

    echo "Using $(node -v) node version"
}


prepare_env() {
    echo "Downloading package.json from wazuh-kibana-app repository"
    if ! curl $wazuh_app_package_json_url -o "/tmp/package.json" ; then
        echo "Error downloading package.json from GitHub."
        exit 1
    fi

    wazuh_version=$(python -c 'import json, os; f=open("/tmp/package.json"); pkg=json.load(f); f.close();\
                    print(pkg["version"])')
    plugin_platform_version=$(python -c 'import json, os; f=open("/tmp/package.json"); pkg=json.load(f); f.close();\
                    plugin_platform_version=pkg.get("pluginPlatform", {}).get("version");\
                    print(plugin_platform_version)')

    echo "|----------------------------$plugin_platform_version-------------------------------|"

    plugin_platform_package_json_url="${plugin_platform_app_raw_repo_url}/${plugin_platform_branch}/package.json"

    echo "Downloading package.json from opensearch-project/OpenSearch-Dashboards repository"
    if ! curl $plugin_platform_package_json_url -o "/tmp/package.json" ; then
        echo "Error downloading package.json from GitHub."
        exit 1
    fi

    plugin_platform_node_version=$(python -c 'import json, os; f=open("/tmp/package.json"); pkg=json.load(f); f.close();\
                          print(pkg["engines"]["node"])')

    plugin_platform_yarn_version=$(python -c 'import json, os; f=open("/tmp/package.json"); pkg=json.load(f); f.close();\
                          print(pkg["engines"]["yarn"])')
}


download_plugin_platform_sources() {
    if ! git clone $plugin_platform_app_repo_url --branch "${plugin_platform_branch}" --depth=1 plugin_platform_source; then
        echo "Error downloading OpenSearch-Dashboards source code from opensearch-project/OpenSearch-Dashboards GitHub repository."
        exit 1
    fi

    mkdir -p plugin_platform_source/plugins
    mv plugin_platform_source ${plugin_platform_dir}
}


install_dependencies () {
    cd ${plugin_platform_dir}
    change_node_version $plugin_platform_node_version
    npm install -g "yarn@${plugin_platform_yarn_version}"

    sed -i 's/node scripts\/build_ts_refs/node scripts\/build_ts_refs --allow-root/' ${plugin_platform_dir}/package.json
    sed -i 's/node scripts\/register_git_hook/node scripts\/register_git_hook --allow-root/' ${plugin_platform_dir}/package.json

    yarn osd bootstrap --skip-opensearch-dashboards-plugins
}


download_wazuh_app_sources() {
    if ! git clone $wazuh_app_clone_repo_url --branch ${wazuh_branch} --depth=1 ${plugin_platform_dir}/plugins/wazuh ; then
        echo "Error downloading the source code from wazuh-kibana-app GitHub repository."
        exit 1
    fi
}


build_package(){

    cd $source_dir

    # Set pkg name
    wazuh_app_pkg_name="invinsense-4.0.zip"

    # Build the package
    yarn
    OPENSEARCH_DASHBOARDS_VERSION=${plugin_platform_version} yarn build --allow-root
    
    mkdir /invinsense
    mv ${build_dir}/*.zip /invinsense/${wazuh_app_pkg_name}
    
    cd $plugin_platform_dir
    yarn build-platform --linux --skip-os-packages --allow-root
    
    platform_pkg_name="opensearch-dashboards-1.2.0.tar.gz"
    
    mv target/opensearch-dashboards-1.2.0-SNAPSHOT-linux-x64.tar.gz /invinsense/${platform_pkg_name}

    if [ "${checksum}" = "yes" ]; then
        cd ${destination_dir} && sha512sum "${wazuh_app_pkg_name}" > "${checksum_dir}/${wazuh_app_pkg_name}".sha512
    fi

    exit 0
}


prepare_env
download_plugin_platform_sources
install_dependencies
download_wazuh_app_sources
build_package
