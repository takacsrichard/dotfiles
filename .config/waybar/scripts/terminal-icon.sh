#!/bin/sh
# nf-fa-terminal U+F120 (EF 84 A0)
icon=$(printf '\xef\x84\xa0')
printf '{"text":"%s","tooltip":"Open terminal (kitty)"}' "$icon"
