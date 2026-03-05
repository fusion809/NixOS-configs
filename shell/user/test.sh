#!/bin/bash
HTML_CONTENT=$(curl -s "https://www.linuxfromscratch.org/lfs/view/development/chapter08/vim.html")
printf '%s' "$HTML_CONTENT" | awk '
        BEGIN { IGNORECASE=1 }
        /<pre [^>]*class="(userinput|root)"[^>]*>/ { in_block=1; print "___BLOCK_START___" }
        in_block { print }
        /<\/pre>/ { in_block=0; print "___BLOCK_END___" }
    ' | perl -0777 -pe 's/<code class="literal">.*?<\/code>//gs' | perl -0777 -pe 's/<[^>]+>//gs' | sed "s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/\"/g" | sed 's/^[[:space:]]*//' | grep -vE "^$|^exec |vim -c |mountpoint -q /dev/shm|mount -t tmpfs devshm" > raw.txt
cat -n raw.txt
