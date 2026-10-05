BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");gsub(/^time:/,"",t[1]);day=t[1]}
    if($i~/^upstream_response_time:/){gsub(/^upstream_response_time:/,"",$i);rt=$i+0}
  }
  sum[day]+=rt
  count[day]++
  if(rt < 0.05) buckets[day]["<50ms"]++
  else if(rt < 0.1) buckets[day]["50-99ms"]++
  else if(rt < 0.2) buckets[day]["100-199ms"]++
  else if(rt < 1) buckets[day]["200-999ms"]++
  else buckets[day][">=1000ms"]++
  vals[day][count[day]]=rt
  days[day]
}
END{
  printf "Date\tAvg(ms)\tMed(ms)\tMax(ms)\t<50ms(%%)\t50-99ms(%%)\t100-199ms(%%)\t200-999ms(%%)\t>=1000ms(%%)\tCount\n"

  m=asorti(days,sorted_d)
  grand_sum=0
  grand_count=0
  for(i=m;i>=1;i--){
    d=sorted_d[i]
    avg=(count[d]>0?sum[d]/count[d]:0)
    n=asort(vals[d])
    if(n%2==1) med=vals[d][int(n/2)+1]
    else med=(vals[d][n/2]+vals[d][n/2+1])/2
    max_val=vals[d][n]
    printf "%s\t%.0f\t%.0f\t%.0f\t%.1f%%\t%.1f%%\t%.1f%%\t%.1f%%\t%.1f%%\t%d\n",d,avg*1000,med*1000,max_val*1000,buckets[d]["<50ms"] / count[d] * 100,buckets[d]["50-99ms"] / count[d] * 100,buckets[d]["100-199ms"] / count[d] * 100,buckets[d]["200-999ms"] / count[d] * 100,buckets[d][">=1000ms"] / count[d] * 100,count[d]
    grand_sum+=sum[d]
    grand_count+=count[d]
    for(bucket in buckets[d]) grand_buckets[bucket]+=buckets[d][bucket]
  }

  grand_avg=(grand_count>0?grand_sum/grand_count:0)
  # collect all values for grand median
  k=0; for(d in vals) for(j in vals[d]) all[++k]=vals[d][j]
  n=asort(all)
  if(n%2==1) grand_med=all[int(n/2)+1]
  else grand_med=(all[n/2]+all[n/2+1])/2
  grand_max=all[n]
  printf "%s\t%.0f\t%.0f\t%.0f\t%.1f%%\t%.1f%%\t%.1f%%\t%.1f%%\t%.1f%%\t%d\n","ALL",grand_avg*1000,grand_med*1000,grand_max*1000,grand_buckets["<50ms"] / grand_count * 100,grand_buckets["50-99ms"] / grand_count * 100,grand_buckets["100-199ms"] / grand_count * 100,grand_buckets["200-999ms"] / grand_count * 100,grand_buckets[">=1000ms"] / grand_count * 100,grand_count
}
