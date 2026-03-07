BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");gsub(/^time:/,"",t[1]);day=t[1]}
    if($i~/^upstream_response_time:/){gsub(/^upstream_response_time:/,"",$i);rt=$i+0}
  }
  sum[day]+=rt
  count[day]++
  vals[day][count[day]]=rt
  days[day]
}
END{
  printf "%-12s %12s %12s %12s %8s %12s\n","Date","Avg(ms)","Med(ms)","Max(ms)","Count","Total(ms)"

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
    printf "%-12s %12.3f %12.3f %12.3f %8d %12.3f\n",d,avg*1000,med*1000,max_val*1000,count[d],sum[d]*1000
    grand_sum+=sum[d]
    grand_count+=count[d]
  }

  grand_avg=(grand_count>0?grand_sum/grand_count:0)
  # collect all values for grand median
  k=0; for(d in vals) for(j in vals[d]) all[++k]=vals[d][j]
  n=asort(all)
  if(n%2==1) grand_med=all[int(n/2)+1]
  else grand_med=(all[n/2]+all[n/2+1])/2
  grand_max=all[n]
  printf "%-12s %12.3f %12.3f %12.3f %8d %12.3f\n","ALL",grand_avg*1000,grand_med*1000,grand_max*1000,grand_count,grand_sum*1000
}
