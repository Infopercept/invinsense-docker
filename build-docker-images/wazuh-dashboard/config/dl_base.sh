WAZUH_CURRENT_VERSION=$(curl --silent https://api.github.com/repos/wazuh/wazuh/releases/latest | grep '\"tag_name\":' | sed -E 's/.*\"([^\"]+)\".*/\1/' | cut -c 2- | sed -e 's/\.//g') && \
WAZUH_IMAGE_VERSION=$(echo $WAZUH_VERSION | sed -e 's/\.//g') && \


if [ "$WAZUH_IMAGE_VERSION" -le "$WAZUH_CURRENT_VERSION" ]; then
 REPOSITORY="packages.wazuh.com"
else 
 REPOSITORY="packages-dev.wazuh.com"
fi
 
# curl -o wazuh-dashboard-base.tar.xz opensearch-dashboards-1.2.0-SNAPSHOT-linux-x64.tar.gz
# tar -xvzf opensearch-dashboard.tar.xz --directory  $INSTALL_DIR --strip-components=1
tar -xf opensearch-dashboards-1.2.0.tar.gz  --directory  $INSTALL_DIR --strip-components=1
