BEGIN {
  FS = "\t"
  count = 0
  print "[portalshit.net] 502/504 エラー通知"
  print ""
  print "以下のリクエストで 502/504 エラーが発生しました。"
  print "（Puma の過負荷またはタイムアウトが原因です）"
}
{
  time_val = ""; method = ""; uri = ""; status = ""; addr = ""; rt = ""
  for (i = 1; i <= NF; i++) {
    if ($i ~ /^time:/)             { gsub(/^time:/, "", $i); time_val = $i }
    if ($i ~ /^request_method:/)   { gsub(/^request_method:/, "", $i); method = $i }
    if ($i ~ /^request_uri:/)      { gsub(/^request_uri:/, "", $i); uri = $i }
    if ($i ~ /^status:/)           { gsub(/^status:/, "", $i); status = $i }
    if ($i ~ /^remote_addr:/)      { gsub(/^remote_addr:/, "", $i); addr = $i }
    if ($i ~ /^request_time:/)     { gsub(/^request_time:/, "", $i); rt = $i }
  }
  count++
  if (max_errors > 0 && count > max_errors) next
  print ""
  print "---"
  print "発生時刻: " time_val
  print "リクエスト: " method " " uri
  print "ステータス: " status
  print "リモートアドレス: " addr
  print "レスポンスタイム: " rt "s"
}
END {
  print "---"
  print ""
  if (max_errors > 0 && count > max_errors) {
    printf "合計: %d件（先頭%d件のみ表示、他%d件省略）\n", count, max_errors, count - max_errors
  } else {
    printf "合計: %d件\n", count
  }
}
