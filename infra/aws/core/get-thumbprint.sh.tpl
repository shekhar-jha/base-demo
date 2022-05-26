HOST=$(curl https://vstoken.actions.githubusercontent.com/.well-known/openid-configuration 2>/dev/null \
| jq -r '.jwks_uri | split("/")[2]')
THMB_PRNT=$(echo | openssl s_client -servername $HOST -showcerts -connect $HOST:443 2> /dev/null \
| sed -n -e '/BEGIN/h' -e '/BEGIN/,/END/H' -e '$x' -e '$p' | tail +2 \
| openssl x509 -fingerprint -noout \
| sed -e "s/.*=//" -e "s/://g" \
| tr "ABCDEF" "abcdef")
echo "{ \"print\" : \"${THMB_PRNT}\" }"
