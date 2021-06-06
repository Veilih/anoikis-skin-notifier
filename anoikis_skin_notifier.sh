#!/bin/bash

cd ~/EVE/logs/Chatlogs

declare -A whs

function update_jnums_db
{
    for jnum in "${!whs[@]}"; do
        unset whs[$jnum]
    done
    while read jnum; do
        whs["$jnum"]="SKIN"
    done < <(curl -s http://anoik.is/api/claimables/available | egrep -o "J[[:digit:]]{6}")
    echo "${#whs[@]} SKINs available in: ${!whs[@]}"
    dbts=$(date +%s)
}

update_jnums_db

logname=$(ls -t Local_* | head -n 1)

echo "Monitoring $logname"

tail -n 0 -F $logname | \
while read line
do
    nextts=$(expr $(date +%s) + 600)
    [ $nextts -gt $dbts ] && update_jnums_db
    for jnum in "${!whs[@]}"; do
        echo "$line" | grep -q "Local : $jnum"
        if [ $? = 0 ]; then
            notify-send -u critical "Good stuff in $jnum" \
                        "Go claim the ${whs[$jnum]}"
	    xdg-open "http://anoik.is/systems/$jnum"
	    break
	fi
    done
done
