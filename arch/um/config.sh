# $Id: f8bfd958e89903f824332510952fc0aa6baa1110 $
#
# This file is sourced AFTER defaults/config.sh; generic options should be set there.
# Arch-specific options that normally shouldn't be changed.
#
KERNEL_MAKE_DIRECTIVE="linux"
KERNEL_MAKE_DIRECTIVE_2=""
KERNEL_BINARY="linux"

ARCH_HAVENOPREPARE=yes
DEFAULT_KERNEL_MAKE="make ARCH=um"
