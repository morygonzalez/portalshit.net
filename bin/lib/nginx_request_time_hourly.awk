BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");split(t[2],hms,":");hour=hms[1]":00"}
    if($i~/^upstream_response_time:/){gsub(/^upstream_response_time:/,"",$i);rt=$i+0}
  }
  sum[hour]+=rt
  count[hour]++
  if(rt < 0.05) buckets[hour]["<50ms"]++
  else if(rt < 0.1) buckets[hour]["50-99ms"]++
  else if(rt < 0.2) buckets[hour]["100-199ms"]++
  else if(rt < 1) buckets[hour]["200-999ms"]++
  else buckets[hour][">=1000ms"]++
  vals[hour][count[hour]]=rt
  hours[hour]
}
END{
  printf "Hour\tAvg(ms)\tMed(ms)\tMax(ms)\t<50ms\t50-99ms\t100-199ms\t200-999ms\t>=1000ms\tCount\n"

  m=asorti(hours,sorted_h)
  grand_sum=0
  grand_count=0
  for(i=1;i<=m;i++){
    h=sorted_h[i]
    avg=(count[h]>0?sum[h]/count[h]:0)
    n=asort(vals[h])
    if(n%2==1) med=vals[h][int(n/2)+1]
    else med=(vals[h][n/2]+vals[h][n/2+1])/2
    max_val=vals[h][n]
    printf "%s\t%.0f\t%.0f\t%.0f\t%d\t%d\t%d\t%d\t%d\t%d\n",h,avg*1000,med*1000,max_val*1000,buckets[h]["<50ms"],buckets[h]["50-99ms"],buckets[h]["100-199ms"],buckets[h]["200-999ms"],buckets[h][">=1000ms"],count[h]
    grand_sum+=sum[h]
    grand_count+=count[h]
    for(bucket in buckets[h]) grand_buckets[bucket]+=buckets[h][bucket]
  }

  grand_avg=(grand_count>0?grand_sum/grand_count:0)
  # collect all values for grand median
  k=0; for(h in vals) for(j in vals[h]) all[++k]=vals[h][j]
  n=asort(all)
  if(n%2==1) grand_med=all[int(n/2)+1]
  else grand_med=(all[n/2]+all[n/2+1])/2
  grand_max=all[n]
  printf "%s\t%.0f\t%.0f\t%.0f\t%d\t%d\t%d\t%d\t%d\t%d\n","ALL",grand_avg*1000,grand_med*1000,grand_max*1000,grand_buckets["<50ms"],grand_buckets["50-99ms"],grand_buckets["100-199ms"],grand_buckets["200-999ms"],grand_buckets[">=1000ms"],grand_count
}
