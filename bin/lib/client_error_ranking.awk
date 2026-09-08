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

  if (ip != "") ip_total[ip]++

  if (status == "404") {
    if (path != "") not_found_path_total[path]++
  } else {
    if (path != "") other_path_total[path]++
  }
}

END {
  dump_simple(ip_total, ip_file)
  dump_simple(not_found_path_total, not_found_path_file)
  dump_simple(other_path_total, other_path_file)
}

# 並べ替えは呼び出し側の sort に任せる。
function dump_simple(total, out,   key) {
  for (key in total) {
    printf "%d %s\n", total[key], key > out
  }
  close(out)
}
