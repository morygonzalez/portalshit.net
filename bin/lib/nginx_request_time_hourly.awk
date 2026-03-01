BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");split(t[2],hms,":");hour=hms[1]":00"}
    if($i~/^request_time:/){gsub(/^request_time:/,"",$i);rt=$i+0}
  }
  sum[hour]+=rt
  count[hour]++
  hours[hour]
}
END{
  printf "%-8s %12s %8s %12s\n","Hour","Avg(ms)","Count","Total(ms)"

  m=asorti(hours,sorted_h)
  grand_sum=0
  grand_count=0
  for(i=1;i<=m;i++){
    h=sorted_h[i]
    avg=(count[h]>0?sum[h]/count[h]:0)
    printf "%-8s %12.3f %8d %12.3f\n",h,avg*1000,count[h],sum[h]*1000
    grand_sum+=sum[h]
    grand_count+=count[h]
  }

  grand_avg=(grand_count>0?grand_sum/grand_count:0)
  printf "%-8s %12.3f %8d %12.3f\n","ALL",grand_avg*1000,grand_count,grand_sum*1000
}
