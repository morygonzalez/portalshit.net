BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");gsub(/^time:/,"",t[1]);date=t[1]}
    if($i~/^status:/){gsub(/^status:/,"",$i);status=$i}
  }
  count[date][status]++
  dates[date]
  statuses[status]
}
END{
  n=asorti(statuses,sorted_s)
  printf "Date"
  for(i=1;i<=n;i++) printf "\t%s",sorted_s[i]
  printf "\tTotal\n"
  m=asorti(dates,sorted_d)
  for(i=1;i<=m;i++){
    d=sorted_d[i]
    printf "%s",d
    total=0
    for(j=1;j<=n;j++){
      v=(count[d][sorted_s[j]]?count[d][sorted_s[j]]:0)
      printf "\t%d",v
      total+=v
    }
    printf "\t%d\n",total
  }
}
