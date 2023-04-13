#!/usr/bin/env bash

set -e
set -u
PS4=" $ "

ARGS=(
	--datadir="$PWD/resources"
)

ARGS+=(
	--buildtype=debug
)

export VALAFLAGS
VALAFLAGS+=" --define=DONT_SPAWN_PROCESSES"

export G_MESSAGES_DEBUG=all

meson setup "${ARGS[@]}" ./build ./

(

set -x

cd ./build
ninja
)

DEBUGGER=()

DEBUGGER+=(
	#gdb --args
	#valgrind --
	#valgrind --tool=callgrind --dump-every-bb=$((1024*1024)) --
)


# Same time format as glib messages.
echo ":: About to launch @ $(date +%H:%M:%S.%3N)"
exec "${DEBUGGER[@]}" ./build/src/eink-friendly-launcher
