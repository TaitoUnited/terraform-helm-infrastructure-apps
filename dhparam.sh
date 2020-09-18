#!/bin/sh

openssl dhparam 4096 2> /dev/null |
  base64 -w 0 |
  sed 's/\(.*\)/{ \"key\": \"\1\" }/g'
