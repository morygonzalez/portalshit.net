BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");date=t[1];gsub(/^time:/,"",date)}
    if($i~/^cache_status:/){gsub(/^cache_status:/,"",$i);cache=$i}
  }
  count[date][cache]++
  dates[date]
  caches[cache]
}
END{
  n=asorti(caches,sorted_c)
  printf "%-12s","Date"
  for(i=1;i<=n;i++) printf "%10s",sorted_c[i]
  printf "%10s %10s\n","Total","HitRate"

  m=asorti(dates,sorted_d)
  for(i=m;i>=1;i--){
    d=sorted_d[i]
    printf "%-12s",d
    total=0; hit=0
    for(j=1;j<=n;j++){
      v=(count[d][sorted_c[j]]?count[d][sorted_c[j]]:0)
      printf "%10d",v
      total+=v
      sum[j]+=v
      if(sorted_c[j]=="HIT") hit=v
    }
    rate=(total>0)?hit/total*100:0
    printf "%10d %9.1f%%\n",total,rate
    grand_total+=total
    grand_hit+=hit
  }

  printf "%-12s","SUM"
  for(j=1;j<=n;j++) printf "%10d",sum[j]
  rate=(grand_total>0)?grand_hit/grand_total*100:0
  printf "%10d %9.1f%%\n",grand_total,rate
}
