BEGIN { FS="\t" }
{
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");split(t[2],hms,":");hour=hms[1]":00"}
    if($i~/^upstream_response_time:/){gsub(/^upstream_response_time:/,"",$i);rt=$i+0}
  }
  sum[hour]+=rt
  count[hour]++
  vals[hour][count[hour]]=rt
  hours[hour]
}
END{
  printf "%-8s %10s %10s %10s %8s\n","Hour","Avg(ms)","Med(ms)","Max(ms)","Count"

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
    printf "%-8s %10.0f %10.0f %10.0f %8d\n",h,avg*1000,med*1000,max_val*1000,count[h]
    grand_sum+=sum[h]
    grand_count+=count[h]
  }

  grand_avg=(grand_count>0?grand_sum/grand_count:0)
  # collect all values for grand median
  k=0; for(h in vals) for(j in vals[h]) all[++k]=vals[h][j]
  n=asort(all)
  if(n%2==1) grand_med=all[int(n/2)+1]
  else grand_med=(all[n/2]+all[n/2+1])/2
  grand_max=all[n]
  printf "%-8s %10.0f %10.0f %10.0f %8d\n","ALL",grand_avg*1000,grand_med*1000,grand_max*1000,grand_count
}
