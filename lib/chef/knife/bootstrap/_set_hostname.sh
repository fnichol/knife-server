#
# Partial: _set_hostname
#
# Functions to set a fully qualified hostname (FQDN) for the Chef Server on
# various platforms
#

set_hostname_for_ubuntu() {
  if hostname | grep -q "$hostname" >/dev/null ; then
    info "Hostname is correct, so skipping..."
    return
  fi

  local host_first="$(echo $hostname | cut -d . -f 1)"
  local hostnames="${hostname} ${host_first}"

  echo $hostname > /etc/hostname
  if egrep -q "^127.0.1.1[[:space:]]" /etc/hosts >/dev/null ; then
    sed -i "s/^\(127[.]0[.]1[.]1[[:space:]]\+\)/\1${hostnames} /" \
      /etc/hosts
  else
    sed -i "s/^\(127[.]0[.]0[.]1[[:space:]]\+.*\)$/\1\n127.0.1.1 ${hostnames} /" \
      /etc/hosts
  fi
  service hostname start
}

set_hostname_for_debian() {
  if hostname --fqdn | grep -q "^${hostname}$" || hostname --short | grep -q "^${hostname}$" ; then
    info "Hostname is correct, so skipping..."
    return
  fi

  local host_first="$(echo $hostname | cut -d . -f 1)"

  sed -r -i "s/^(127[.]0[.]1[.]1[[:space:]]+).*$/\\1${hostname} ${host_first}/" \
    /etc/hosts
  echo $host_first > /etc/hostname
  hostname -F /etc/hostname
}

set_hostname_for_el() {
  if hostname | grep -q "$hostname" > /dev/null ; then
    info "-----> Hostname is correct, so skipping..."
    return
  fi

  local host_first="$(echo $hostname | cut -d . -f 1)"
  local hostnames="${hostname} ${host_first}"

  sed -i "s/HOSTNAME=.*/HOSTNAME=${hostname}/" /etc/sysconfig/network

  if egrep -q "^127.0.1.1[[:space:]]" /etc/hosts >/dev/null ; then
    sed -i "s/^\(127[.]0[.]1[.]1[[:space:]]\+\)/\1${hostnames} /" /etc/hosts
  else
    sed -i "s/^\(127[.]0[.]0[.]1[[:space:]]\+.*\)$/\1\n127.0.1.1 ${hostnames} /" \
      /etc/hosts
  fi
  /bin/hostname ${hostname}
}
