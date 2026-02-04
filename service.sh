#!/system/bin/sh
# Late-boot launcher for mosey_server (KernelSU/Magisk service.d style)
# Goal: start mosey_server after boot with robust logging and basic self-diagnostics.

MODDIR="${0%/*}"
LOGDIR="/data/adb/mosey-extended"
LOGFILE="$LOGDIR/service.log"
RUNLOG="$LOGDIR/mosey_server.log"
PIDFILE="$LOGDIR/mosey_server.pid"

mkdir -p "$LOGDIR" 2>/dev/null
chmod 0700 "$LOGDIR" 2>/dev/null

ts() { /system/bin/date '+%Y-%m-%d %H:%M:%S%z' 2>/dev/null || echo "no-date"; }
log() { echo "$(ts) [mosey-extended] $*" >>"$LOGFILE"; }

# Best-effort: discover the real runtime path. In theory this should exist as /vendor/bin/mosey_server
BIN="/vendor/bin/mosey_server"
[ -x "$BIN" ] || BIN="/system/vendor/bin/mosey_server"
[ -x "$BIN" ] || BIN="$MODDIR/system/vendor/bin/mosey_server"  # fallback (may not work)

log "service.sh invoked (MODDIR=$MODDIR, BIN=$BIN, uid=$(id -u 2>/dev/null), ctx=$(id -Z 2>/dev/null))"

# Wait for Android boot to complete (and for KSU mounts to settle)
i=0
while [ "$i" -lt 180 ]; do
  bc="$(getprop sys.boot_completed 2>/dev/null)"
  if [ "$bc" = "1" ]; then
    break
  fi
  i=$((i+1))
  [ $((i % 10)) -eq 0 ] && log "waiting for sys.boot_completed=1 (elapsed=${i}s, current=$bc)"
  /system/bin/sleep 1
done

log "boot_completed=$(getprop sys.boot_completed 2>/dev/null) dev_bootcomplete=$(getprop dev.bootcomplete 2>/dev/null)"

# Avoid duplicate instances
if [ -f "$PIDFILE" ]; then
  oldpid="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
    log "already running (pid=$oldpid), exiting"
    exit 0
  fi
fi

# Snapshot a few details for debugging
if [ -e "$BIN" ]; then
  ls -lZ "$BIN" >>"$LOGFILE" 2>/dev/null
else
  log "ERROR: binary not found at $BIN"
  log "HINT: check that KSU overlay exposes /vendor/bin/mosey_server"
  exit 1
fi

# Try to start using init service hook first (will only work if init parsed mosey.rc)
# This usually fails on your ROM, but logging it is valuable.
log "attempting: setprop ctl.start mosey_server (may fail if service is unknown)"
setprop ctl.start mosey_server 2>/dev/null
/system/bin/sleep 1
svc_state="$(getprop init.svc.mosey_server 2>/dev/null)"
if [ -n "$svc_state" ]; then
  log "init reports init.svc.mosey_server=$svc_state"
  if [ "$svc_state" = "running" ]; then
    log "init-managed service started successfully; done"
    exit 0
  fi
else
  log "init.svc.mosey_server is empty (service likely not registered with init)"
fi

# Fallback: launch directly (note: SELinux domain will likely be wrong; expect binder registration failures)
log "fallback: launching $BIN directly (stdout/stderr -> $RUNLOG)"
# Use sh -c to ensure redirections work on all toybox/toolbox variants
/system/bin/sh -c "\"$BIN\" >>\"$RUNLOG\" 2>&1 & echo \$! >\"$PIDFILE\"" 2>>"$LOGFILE"

pid="$(cat "$PIDFILE" 2>/dev/null)"
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
  log "mosey_server started (pid=$pid)"
else
  log "ERROR: failed to start mosey_server (pidfile='$pid')"
  # Dump last lines of RUNLOG into LOGFILE for convenience
  if [ -f "$RUNLOG" ]; then
    log "---- tail $RUNLOG ----"
    tail -n 80 "$RUNLOG" >>"$LOGFILE" 2>/dev/null
    log "---- end tail ----"
  fi
  exit 1
fi

# Post-start quick checks
log "post-start ctx=$(cat /proc/$pid/attr/current 2>/dev/null)"
log "post-start cmdline=$(tr '\0' ' ' </proc/$pid/cmdline 2>/dev/null)"

# Give it a moment to register binder service etc.
system/bin/sleep 2

# If it died quickly, capture logs
if ! kill -0 "$pid" 2>/dev/null; then
  log "process exited quickly (pid=$pid)"
  if [ -f "$RUNLOG" ]; then
    log "---- tail $RUNLOG ----"
    tail -n 120 "$RUNLOG" >>"$LOGFILE" 2>/dev/null
    log "---- end tail ----"
  fi
  exit 1
fi

log "service.sh completed (pid=$pid); check $RUNLOG for mosey_server output"
exit 0
