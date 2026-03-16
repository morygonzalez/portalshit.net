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
  printf "%-12s","Date"
  for(i=1;i<=n;i++) printf "%6s",sorted_s[i]
  printf "%7s\n","Total"

  m=asorti(dates,sorted_d)
  for(i=m;i>=1;i--){
    d=sorted_d[i]
    printf "%-12s",d
    total=0
    for(j=1;j<=n;j++){
      v=(count[d][sorted_s[j]]?count[d][sorted_s[j]]:0)
      printf "%6d",v
      total+=v
    }
    printf "%7d\n",total
  }
}
