#
# Partial: _common.sh
#
# Common functions used by the rest of the program.
#

banner()  { echo "-----> $*" ; }
info()    { echo "       $*" ; }
warn()    { echo ">>>>>> $*" >&2 ; }

report_bug() {
  warn "Please file a bug report at https://github.com/fnichol/knife-server/issues"
  warn " "
  warn "Please detail your operating system, version and any other relevant details"
}

exists() {
  if command -v $1 &>/dev/null
  then
    return 0
  else
    return 1
  fi
}
