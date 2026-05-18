#!/usr/bin/env bash

for d in /sys/bus/usb/devices/*; do
  [[ -f "$d/idVendor" ]] || continue
  v=$(tr -d '\n' <"$d/idVendor")
  p=$(tr -d '\n' <"$d/idProduct")
  n=$(tr -d '\n' <"$d/product")
  printf '%s\t%s:%s\tcontrol=%s\truntime=%s\t%s\n' "${d##*/}" "$v" "$p" "$(cat "$d/power/control")" "$(cat "$d/power/runtime_status")" "$n"
done |
  column -s $'\t' -t |
  sort -h
