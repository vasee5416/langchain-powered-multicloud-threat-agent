#!/bin/bash
# tools/actions.sh
# SOC response actions simulator

ACTION=$1
TARGET=$2

case $ACTION in
  block_ip)
    echo "[Responder] Blocking suspicious IP: $TARGET"
    # Simulate block (don't break networking)
    echo "iptables -A INPUT -s $TARGET -j DROP "
    ;;

  isolate_vm)
    echo "[Responder] Isolating VM for IP: $TARGET"
    # Simulate isolation
    echo "ip link set eth0 down "
    ;;

  alert_only)
    echo "[Responder] ALERT: Threat detected for IP: $TARGET. No active block performed."
    ;;

  *)
    echo "[Responder] No valid action specified."
    ;;
esac

