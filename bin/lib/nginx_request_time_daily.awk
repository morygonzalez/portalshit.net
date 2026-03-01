BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");gsub(/^time:/,"",t[1]);day=t[1]}
    if($i~/^upstream_response_time:/){gsub(/^upstream_response_time:/,"",$i);rt=$i+0}
  }
  sum[day]+=rt
  count[day]++
  days[day]
}
END{
  printf "%-12s %12s %8s %12s\n","Date","Avg(ms)","Count","Total(ms)"

  m=asorti(days,sorted_d)
  grand_sum=0
  grand_count=0
  for(i=m;i>=1;i--){
    d=sorted_d[i]
    avg=(count[d]>0?sum[d]/count[d]:0)
    printf "%-12s %12.3f %8d %12.3f\n",d,avg*1000,count[d],sum[d]*1000
    grand_sum+=sum[d]
    grand_count+=count[d]
  }

  grand_avg=(grand_count>0?grand_sum/grand_count:0)
  printf "%-12s %12.3f %8d %12.3f\n","ALL",grand_avg*1000,grand_count,grand_sum*1000
}
