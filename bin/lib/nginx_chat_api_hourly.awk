BEGIN { FS="\t" }
{
  hour=""; uri=""; status=""
  for(i=1;i<=NF;i++){
    if($i~/^time:/){split($i,t,"T");split(t[2],hms,":");hour=hms[1]":00"}
    if($i~/^request_uri:/){gsub(/^request_uri:/,"",$i);uri=$i}
    if($i~/^status:/){gsub(/^status:/,"",$i);status=$i}
  }
  sub(/\?.*$/,"",uri)
  if(uri !~ /^\/api\/chat\//) next

  hours[hour]
  total[hour]++
  if(uri=="/api/chat/messages") messages[hour]++
  else if(uri=="/api/chat/ogp") ogp[hour]++
  else other[hour]++
  if(status=="429") limited[hour]++
}
END{
  printf "Hour\tMessages\tOGP\tOther\tTotal\t429\n"

  m=asorti(hours,sorted_h)
  grand_messages=0
  grand_ogp=0
  grand_other=0
  grand_total=0
  grand_limited=0
  for(i=1;i<=m;i++){
    h=sorted_h[i]
    printf "%s\t%d\t%d\t%d\t%d\t%d\n",h,messages[h],ogp[h],other[h],total[h],limited[h]
    grand_messages+=messages[h]
    grand_ogp+=ogp[h]
    grand_other+=other[h]
    grand_total+=total[h]
    grand_limited+=limited[h]
  }

  printf "%s\t%d\t%d\t%d\t%d\t%d\n","ALL",grand_messages,grand_ogp,grand_other,grand_total,grand_limited
}
