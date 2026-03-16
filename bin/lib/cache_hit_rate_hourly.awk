BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");split(t[2],hms,":");hour=hms[1]":00"}
    if($i~/^cache_status:/){gsub(/^cache_status:/,"",$i);cache=$i}
  }
  count[hour][cache]++
  hours[hour]
}
END{
  printf "%-8s %7s %7s %7s %7s %7s\n","Hour","HitRate","HIT","MISS","EXPIRED","Total"

  m=asorti(hours,sorted_h)
  for(i=1;i<=m;i++){
    h=sorted_h[i]
    hit=(count[h]["HIT"]?count[h]["HIT"]:0)
    miss=(count[h]["MISS"]?count[h]["MISS"]:0)
    expired=(count[h]["EXPIRED"]?count[h]["EXPIRED"]:0)
    total=hit+miss+expired
    rate=(total>0)?hit/total*100:0
    printf "%-8s %6.1f%% %7d %7d %7d %7d\n",h,rate,hit,miss,expired,total
    grand_hit+=hit; grand_miss+=miss; grand_expired+=expired; grand_total+=total
  }

  rate=(grand_total>0)?grand_hit/grand_total*100:0
  printf "%-8s %6.1f%% %7d %7d %7d %7d\n","SUM",rate,grand_hit,grand_miss,grand_expired,grand_total
}
