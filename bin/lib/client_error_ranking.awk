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

  if (status == "404") {
    if (ip != "") not_found_ip_total[ip]++
    if (path != "") not_found_path_total[path]++
  } else {
    if (ip != "") {
      other_ip_total[ip]++
      other_ip_status[ip][status]++
    }
    if (path != "") {
      other_path_total[path]++
      other_path_status[path][status]++
    }
  }
}

END {
  dump_simple(not_found_ip_total, not_found_ip_file)
  dump_simple(not_found_path_total, not_found_path_file)
  dump_with_status(other_ip_total, other_ip_status, other_ip_file)
  dump_with_status(other_path_total, other_path_status, other_path_file)
}

# 並べ替えは呼び出し側の sort に任せる。
function dump_simple(total, out,   key) {
  for (key in total) {
    printf "%d %s\n", total[key], key > out
  }
  close(out)
}

function dump_with_status(total, by_status, out,   key, n, sorted, breakdown, j) {
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
