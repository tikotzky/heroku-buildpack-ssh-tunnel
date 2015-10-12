#!/usr/bin/env bash

# echoerr prints to STDERR
echoerr() { echo "$@" 1>&2; }

# Run only if there are tunnels to be setup
if [ "$SSH_TUNNELS" == "" ]
then
  echo "\$SSH_TUNNELS undefined"
  exit 0
fi

# Run only if autossh is installed
if [ ! -f "`which autossh`" ]
then
  echoerr "autossh not installed"
  exit 0
fi

mkdir -p ${HOME}/.ssh
chmod 700 ${HOME}/.ssh

# Copy public key env variable into a file
if [ "${SSH_PUBLIC_KEY}" != "" ]
then
  echo "${SSH_PUBLIC_KEY}" > ${HOME}/.ssh/id_rsa.pub
  chmod 644 ${HOME}/.ssh/id_rsa.pub
else
  echo "\$SSH_PUBLIC_KEY undefined"
fi

# Copy private key env variable into a file
if [ "${SSH_PRIVATE_KEY}" != "" ]
then
  echo "${SSH_PRIVATE_KEY}" > ${HOME}/.ssh/id_rsa
  chmod 600 ${HOME}/.ssh/id_rsa
else
  echo "\$SSH_PUBLIC_KEY undefined"
fi

# SSH_TUNNELS variable contains a comma separated list of tunnesl with the following format:
#  user@ssh-server:ssh-port|127.0.0.1:local-port:target-host:remote-port

# Monitoring ports
M=5050

for tunnel in `echo $SSH_TUNNELS | tr , ' '`
do
  echo "# $tunnel"
  if [[ "$tunnel" == *"\""* ]]; then
    echoerr "tunnel declaration contains a \""
    exit 1
  fi
  eval `echo $tunnel | awk -F'|' '{ printf("ssh_opts=\"%s\"\ntunnel_opts=\"%s\"\n",$1,$2); }'`
  if [ "$tunnel_opts" == "" ]; then
    echoerr "tunnel options missing from $tunnel"
    exit 1
  fi
  eval `echo $ssh_opts | awk -F':' '{ printf("target_ssh=\"%s\"\nssh_port=\"%s\"\n",$1,$2); }'`
  if [ "$ssh_port" == "" ]; then ssh_port="22"; fi
  if [[ "$target_ssh" == *"@"* ]]; then
    ssh_host=`echo $target_ssh | awk -F@ '{print $2}'`
  else
    ssh_host=$target_ssh
  fi

  # Auto add the host to known_hosts
  # This is to avoid the authenticity of host question that otherwise will halt autossh from setting up the tunnel.
  #
  # Ex:
  # The authenticity of host '[hostname] ([IP address])' can't be established.
  # RSA key fingerprint is [fingerprint].
  # Are you sure you want to continue connecting (yes/no)?

  ssh-keyscan -p $ssh_port $ssh_host >> ${HOME}/.ssh/known_hosts

  # Setup SSH Tunnel
  #
  # autossh will monitor port $M If the connection dies autossh will automatically set up a new one.
  # ServerAliveInterval: Number of seconds between sending a packet to the server (to keep the connection alive).
  # ClientAliveCountMax: Number of above ServerAlive packets before closing the connection. Autossh will create a new connection when this happens.

  autossh -f -M $M -N -o "ServerAliveInterval 10" -o "ServerAliveCountMax 3" -L $tunnel_opts $target_ssh -p $ssh_port

  # Increment monitored port by two since two ports are used in monitoring $M and $M+1
  M=$(($M + 2))

done
