function most_common {
  sed 's/^: [0-9]*:[0-9]*;//' "$HISTFILE" \
    | awk '{count[$1]++; total++} END{for(cmd in count) printf "%d\t%.1f%%\t%s\n", count[cmd], count[cmd]/total*100, cmd}' \
    | sort -rn | head -10
}

function most_common_pairs {
  sed 's/^: [0-9]*:[0-9]*;//' "$HISTFILE" \
    | awk 'NF{cmd=$1; if(prev!=""){pair[prev" -> "cmd]++; total++}; prev=cmd} END{for(p in pair) printf "%d\t%.1f%%\t%s\n", pair[p], pair[p]/total*100, p}' \
    | sort -rn | head -10
}

