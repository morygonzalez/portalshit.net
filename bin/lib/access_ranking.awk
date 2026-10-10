# Count only article permalinks (/YYYY/MM/DD/slug), not listing or static pages.
# input_format: ltsv (default), paths (legacy script), ranking (GA counts).
BEGIN { FS = "\t" }

{
  path = ""
  views = 1

  if (input_format == "ranking") {
    line = $0
    sub(/^[[:space:]]+/, "", line)
    fields = split(line, values, /[[:space:]]+/)
    if (fields < 2 || values[1] !~ /^[0-9]+$/) next
    views = values[1] + 0
    path = values[2]
  } else if (input_format == "paths") {
    path = $0
  } else {
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^request_uri:/) {
        path = $i
        sub(/^request_uri:/, "", path)
        break
      }
    }
  }

  sub(/\?.*/, "", path)
  if (path ~ /^\/[0-9][0-9][0-9][0-9]\/[0-9][0-9]\/[0-9][0-9]\/[^\/[:space:]]+$/) {
    count[path] += views
  }
}

END {
  for (path in count) print count[path], path
}
