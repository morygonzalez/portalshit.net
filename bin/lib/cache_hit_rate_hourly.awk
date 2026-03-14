BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");split(t[2],hms,":");hour=hms[1]":00"}
    if($i~/^cache_status:/){gsub(/^cache_status:/,"",$i);cache=$i}
  }
  count[hour][cache]++
  hours[hour]
  caches[cache]
}
END{
  n=asorti(caches,sorted_c)
  printf "%-8s","Hour"
  for(i=1;i<=n;i++) printf "%10s",sorted_c[i]
  printf "%10s %10s\n","Total","HitRate"

  m=asorti(hours,sorted_h)
  for(i=1;i<=m;i++){
    h=sorted_h[i]
    printf "%-8s",h
    total=0; hit=0
    for(j=1;j<=n;j++){
      v=(count[h][sorted_c[j]]?count[h][sorted_c[j]]:0)
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

  printf "%-8s","SUM"
  for(j=1;j<=n;j++) printf "%10d",sum[j]
  rate=(grand_total>0)?grand_hit/grand_total*100:0
  printf "%10d %9.1f%%\n",grand_total,rate
}
