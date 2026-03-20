BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");date=t[1];gsub(/^time:/,"",date)}
    if($i~/^cache_status:/){gsub(/^cache_status:/,"",$i);cache=$i}
  }
  count[date][cache]++
  dates[date]
}
END{
  printf "Date\tHitRate\tHIT\tMISS\tEXPIRED\tTotal\n"

  m=asorti(dates,sorted_d)
  for(i=m;i>=1;i--){
    d=sorted_d[i]
    hit=(count[d]["HIT"]?count[d]["HIT"]:0)
    miss=(count[d]["MISS"]?count[d]["MISS"]:0)
    expired=(count[d]["EXPIRED"]?count[d]["EXPIRED"]:0)
    total=hit+miss+expired
    rate=(total>0)?hit/total*100:0
    printf "%s\t%.1f%%\t%d\t%d\t%d\t%d\n",d,rate,hit,miss,expired,total
    grand_hit+=hit; grand_miss+=miss; grand_expired+=expired; grand_total+=total
  }

  rate=(grand_total>0)?grand_hit/grand_total*100:0
  printf "%s\t%.1f%%\t%d\t%d\t%d\t%d\n","SUM",rate,grand_hit,grand_miss,grand_expired,grand_total
}
