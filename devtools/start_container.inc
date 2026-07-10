export REPO_ROOT=$(pwd)
devtools/flutter_bolt_dev_container.sh start \
	--project-path "${APP_DIR}" \
	--bolt-name "${BOLT_NAME}" \
	--stb-ip "${STB_IP}" \
	--application-recipe "${FLUTTER_APP}" \
	--downloads-path "${OE_DOWNLOADS}" \
	--sstate-path "${OE_SSTATE_PATH}"
