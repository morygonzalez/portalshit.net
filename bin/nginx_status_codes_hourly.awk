BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");split(t[2],hms,":");hour=hms[1]":00"}
    if($i~/^status:/){gsub(/^status:/,"",$i);status=$i}
  }
  count[hour][status]++
  hours[hour]
  statuses[status]
}
END{
  n=asorti(statuses,sorted_s)
  printf "%-8s","Hour"
  for(i=1;i<=n;i++) printf "%8s",sorted_s[i]
  printf "%10s\n","Total"

  m=asorti(hours,sorted_h)
  for(i=1;i<=m;i++){
    h=sorted_h[i]
    printf "%-8s",h
    total=0
    for(j=1;j<=n;j++){
      v=(count[h][sorted_s[j]]?count[h][sorted_s[j]]:0)
      printf "%8d",v
      total+=v
    }
    printf "%10d\n",total
  }
}
