#!/bin/ash
set -e

# Params
#   $1 name
#   $2 connect-to
create_tinc_conf() {
  cat << EOF | sed 's/^  //' > /etc/tinc/tinc.conf
  Name = $1
  AddressFamily = ipv4
  Interface = tun0
EOF
  
  if [ ! -z "$2" ]; then
    cat << EOF | sed 's/^    //' >> /etc/tinc/tinc.conf
    ConnectTo = $2
EOF
  fi
}

# Params
#   $1 internal ip address
create_tinc_up() {
  cat << EOF | sed 's/^  //' > /etc/tinc/tinc-up 
  ifconfig \$INTERFACE $1 netmask 255.255.255.0
EOF
}

create_tinc_down() {
  cat << EOF | sed 's/^  //' > /etc/tinc/tinc-down
  ifconfig \$INTERFACE down
EOF
}

generate_keys() {
  tincd -c /etc/tinc -K
}

# Params
#   $1 external ip address
add_address_to_hosts_file() {
  cat << EOF | sed 's/^  //' >> "/etc/tinc/hosts/$1"
  Address = $1
EOF
}

# Params
#   $1 name
#   $2 internal ip address
#   $3 external ip address
update_hosts_file() {
  if [ ! -z "$3" ]; then
    add_address_to_hosts_file "$3"
  fi

  cat << EOF | sed 's/^  //' >> "/etc/tinc/hosts/$1"
  Subnet = $2/32
EOF
}

init_usage() {
  echo "Usage:"
  echo "  init [OPTIONS]"
  echo
  echo "  OPTIONS"
  echo "    -n, --name        [Required] Specify the name of the host"
  echo "    -i, --internal    [Required] Specify the internal ip address"
  echo "    -e, --external               Specify the external ip address"
  echo "    -c, --connect-to             Specify the name of the host to connect to"
  echo
}

# Params
#   $1 name
#   $2 internal ip address
#   $3 external ip address
init() {
  options=$(getopt -o n:i:e:c: \
    --long name: \
    --long internal: \
    --long external: \
    --long connect-to: \
    -- "$@")
  if [ ! $? -eq 0 ]; then
      echo "Incorrect option provided"
      exit 1
  fi

  eval set -- "$options"
  while true; do
    case "$1" in
      -n|--name)
        shift
        NAME="$1"
        ;;
      -i|--internal)
        shift
        INTERNAL="$1"
        ;;
      -e|--external)
        shift
        EXTERNAL="$1"
        ;;
      -c|--connect-to)
        shift
        CONNECT_TO="$1"
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
      esac
      shift
  done

  if [[ -z "$NAME" || -z "$INTERNAL" ]]; then
    init_usage
    exit 1;
  fi

  echo "Initializing tinc"
  mkdir -p "/etc/tinc/hosts"

  create_tinc_conf "$NAME" "$CONNECT_TO"
  create_tinc_up "$INTERNAL"
  create_tinc_down

  chmod +x /etc/tinc/tinc-up
  chmod +x /etc/tinc/tinc-down

  generate_keys

  update_hosts_file "$NAME" "$INTERNAL" "$EXTERNAL"
}

##
# Main
##
if [ "$1" = "init" ]; then
  shift
  init "$@"
elif [ -z "$1" ]; then
  if [ ! -c /dev/net/tun ]; then
    echo "Configuring tunnel"
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
  fi

  echo "Starting tinc"
  tincd -n . -D -U nobody
else
  exec "$@"
fi
