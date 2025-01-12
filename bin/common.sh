#!/bin/bash

# 定数定義
readonly APP_DIR='/var/www/app/portalshit'
readonly LOG_DIR=$(realpath "${APP_DIR}/log")
readonly LOG_AGGREGATION_DIR="${APP_DIR}/public/log-aggregation"
readonly CONFIG_DIR="${APP_DIR}/bin/conf"
readonly UA_TO_IGNORE=$(cat "${CONFIG_DIR}/ua_to_ignore.txt" 2>/dev/null || echo "")
readonly REFERER_TO_IGNORE=$(cat "${CONFIG_DIR}/referer_to_ignore.txt" 2>/dev/null || echo "")
readonly REQUEST_PATH_TO_IGNORE=$(cat "${CONFIG_DIR}/request_path_to_ignore.txt" 2>/dev/null || echo "")
readonly IP_TO_IGNORE=$(cat "${LOG_AGGREGATION_DIR}/ip-to-ignore.txt")

# ディレクトリ確認と作成
mkdir -p "${LOG_AGGREGATION_DIR}"

# 共通処理関数
filter_logs() {
  local period=${1:-"*"}
  local status=${2:-"*"}

  find "${LOG_DIR}" -name "access.log*" \
    | xargs zcat -f \
    | grep -P "status:${status}" \
    | grep -vP "remote_addr:\(${IP_TO_IGNORE}\)" \
    | grep -viP "${UA_TO_IGNORE}" \
    | grep -viP "${REFERER_TO_IGNORE}" \
    | grep -vP "request_uri:${REQUEST_PATH_TO_IGNORE}" \
    | filter_by_date "${period}"
}

filter_by_date() {
  local filter_date=""
  case "$1" in
    all)
      filter_date="*"
      ;;
    today|yesterday)
      filter_date=$(date -d "$1" "+%Y-%m-%d")
      ;;
    [0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9])
      filter_date="${1}"
      ;;
    *)
      filter_date="*"
      ;;
  esac

  if [[ "$filter_date" == "*" || "$filter_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    grep "time:${filter_date}"
  else
    echo "Invalid date format: ${filter_date}" >&2
    return 1
  fi
}
