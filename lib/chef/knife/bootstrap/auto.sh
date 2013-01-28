set -xe

machine=$(echo -e `uname -m`)

# Retrieve Platform and Platform Version
if [ -f "/etc/lsb-release" ];
then
  platform=$(grep DISTRIB_ID /etc/lsb-release | cut -d "=" -f 2 | tr '[A-Z]' '[a-z]')
  platform_version=$(grep DISTRIB_RELEASE /etc/lsb-release | cut -d "=" -f 2)
elif [ -f "/etc/debian_version" ];
then
  platform="debian"
  platform_version=$(echo -e `cat /etc/debian_version`)
elif [ -f "/etc/redhat-release" ];
then
  platform=$(sed 's/^\(.\+\) release.*/\1/' /etc/redhat-release | tr '[A-Z]' '[a-z]')
  platform_version=$(sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/redhat-release)

  # If /etc/redhat-release exists, we act like RHEL by default
  if [ "$platform" = "fedora" ];
  then
    # Change platform version for use below.
    platform_version="6.0"
  fi
  platform="el"
elif [ -f "/etc/system-release" ];
then
  platform=$(sed 's/^\(.\+\) release.\+/\1/' /etc/system-release | tr '[A-Z]' '[a-z]')
  platform_version=$(sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/system-release | tr '[A-Z]' '[a-z]')
  # amazon is built off of fedora, so act like RHEL
  if [ "$platform" = "amazon linux ami" ];
  then
    platform="el"
    platform_version="6.0"
  fi
# Apple OS X
elif [ -f "/usr/bin/sw_vers" ];
then
  platform="mac_os_x"
  # Matching the tab-space with sed is error-prone
  platform_version=$(sw_vers | awk '/^ProductVersion:/ { print $2 }')

  major_version=$(echo $platform_version | cut -d. -f1,2)
  case $major_version in
    "10.6") platform_version="10.6" ;;
    "10.7") platform_version="10.7" ;;
    "10.8") platform_version="10.7" ;;
    *) echo "No builds for platform: $major_version"
       report_bug
       exit 1
       ;;
  esac

  # x86_64 Apple hardware often runs 32-bit kernels (see OHAI-63)
  x86_64=$(sysctl -n hw.optional.x86_64)
  if [ $x86_64 -eq 1 ]; then
    machine="x86_64"
  fi
elif [ -f "/etc/release" ];
then
  platform="solaris2"
  machine=$(/usr/bin/uname -p)
  platform_version=$(/usr/bin/uname -r)
elif [ -f "/etc/SuSE-release" ];
then
  if grep -q 'Enterprise' /etc/SuSE-release;
  then
      platform="sles"
      platform_version=$(awk '/^VERSION/ {V = $3}; /^PATCHLEVEL/ {P = $3}; END {print V "." P}' /etc/SuSE-release)
  else
      platform="suse"
      platform_version=$(awk '/^VERSION =/ { print $3 }' /etc/SuSE-release)
  fi
fi

if [ "x$platform" = "x" ];
then
  echo "Unable to determine platform version!"
  report_bug
  exit 1
fi

# Mangle $platform_version to pull the correct build
# for various platforms
major_version=$(echo $platform_version | cut -d. -f1)
case $platform in
  "el")
    case $major_version in
      "5") platform_version="5" ;;
      "6") platform_version="6" ;;
    esac
    ;;
  "debian")
    case $major_version in
      "5") platform_version="6";;
      "6") platform_version="6";;
    esac
    ;;
esac

if [ "x$platform_version" = "x" ];
then
  echo "Unable to determine platform version!"
  report_bug
  exit 1
fi

echo $platform
echo $platform_version
