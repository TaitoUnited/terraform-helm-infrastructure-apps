#!/bin/sh

file="dhparam$1"
cd "$2"

if [ ! -f "${file}" ]; then
  openssl dhparam 4096 2> /dev/null | base64 -w 0 > "${file}"
fi
sed 's/\(.*\)/{ \"key\": \"\1\" }/g' "${file}"
