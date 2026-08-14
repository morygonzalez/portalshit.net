BEGIN { FS="\t" }
{
  day=""; uri=""; status=""
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");gsub(/^time:/,"",t[1]);day=t[1]}
    if($i~/^request_uri:/){gsub(/^request_uri:/,"",$i);uri=$i}
    if($i~/^status:/){gsub(/^status:/,"",$i);status=$i}
  }
  sub(/\?.*$/,"",uri)
  if(uri !~ /^\/api\/chat\//) next

  days[day]
  total[day]++
  if(uri=="/api/chat/messages") messages[day]++
  else if(uri=="/api/chat/ogp") ogp[day]++
  else other[day]++
  if(status=="429") limited[day]++
}
END{
  printf "Date\tMessages\tOGP\tOther\tTotal\t429\n"

  m=asorti(days,sorted_d)
  grand_messages=0
  grand_ogp=0
  grand_other=0
  grand_total=0
  grand_limited=0
  for(i=m;i>=1;i--){
    d=sorted_d[i]
    printf "%s\t%d\t%d\t%d\t%d\t%d\n",d,messages[d],ogp[d],other[d],total[d],limited[d]
    grand_messages+=messages[d]
    grand_ogp+=ogp[d]
    grand_other+=other[d]
    grand_total+=total[d]
    grand_limited+=limited[d]
  }

  printf "%s\t%d\t%d\t%d\t%d\t%d\n","ALL",grand_messages,grand_ogp,grand_other,grand_total,grand_limited
}
