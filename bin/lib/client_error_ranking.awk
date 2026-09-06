BEGIN { FS = "\t" }

{
  ip = ""
  path = ""
  status = ""
  for (i = 1; i <= NF; i++) {
    if ($i ~ /^remote_addr:/) {
      ip = $i
      sub(/^remote_addr:/, "", ip)
    } else if ($i ~ /^request_uri:/) {
      path = $i
      sub(/^request_uri:/, "", path)
    } else if ($i ~ /^status:/) {
      status = $i
      sub(/^status:/, "", status)
    }
  }

  if (status !~ /^4[0-9][0-9]$/) {
    next
  }

  if (ip != "") {
    ip_total[ip]++
    ip_status[ip][status]++
  }
  if (path != "") {
    path_total[path]++
    path_status[path][status]++
  }
}

END {
  dump(ip_total, ip_status, ip_file)
  dump(path_total, path_status, path_file)
}

# 「合計 キー ステータス内訳」を出力する。並べ替えは呼び出し側の sort に任せる。
function dump(total, by_status, out,   key, n, sorted, breakdown, j) {
  for (key in total) {
    breakdown = ""
    n = asorti(by_status[key], sorted)
    for (j = 1; j <= n; j++) {
      breakdown = breakdown (breakdown == "" ? "" : " ") sorted[j] ":" by_status[key][sorted[j]]
    }
    printf "%d %s %s\n", total[key], key, breakdown > out
  }
  close(out)
}
