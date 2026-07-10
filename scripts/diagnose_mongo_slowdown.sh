#!/bin/bash

# Collects a read-only diagnostic report to determine whether the recent mongo
# changes (bounded WiredTiger cache / container memory limit / single-node
# replica set + journal-acknowledged writes, see MONGODB.md) are responsible
# for slow batch processing on this server.
#
# Usage:
#   ./scripts/diagnose_mongo_slowdown.sh [project_prefix]
#
# The optional project_prefix must match the PROJECT_PREFIX build setting
# (container names become e.g. "myprefix_mongo"). Output is written to stdout
# and to mongo_diag_<host>_<timestamp>.txt in the current directory.
#
# The script only reads state (docker inspect/logs/stats, mongo serverStatus,
# /proc). It does not change any configuration.

PREFIX="${1:-}"

MONGO_CONTAINER="${PREFIX}mongo"
DBSERVER_CONTAINER="${PREFIX}dbserver"
AUDITPROC_CONTAINER="${PREFIX}service_audit_processing"
INTERCONNECT_CONTAINER="${PREFIX}data_interconnector"

SAMPLE_SECONDS=30

REPORT_FILE="mongo_diag_$(hostname -s 2>/dev/null || echo host)_$(date +%Y%m%d_%H%M%S).txt"

section () {
    echo ""
    echo "======================================================================"
    echo "== $1"
    echo "======================================================================"
}

have_container () {
    docker inspect "$1" > /dev/null 2>&1
}

collect_report () {

section "Report info"
echo "Generated: $(date -Is)"
echo "Hostname:  $(hostname)"
echo "Kernel:    $(uname -sr)"
echo "Uptime:   $(uptime)"

# ---------------------------------------------------------------------------------------------------------------------
section "Host memory + swap"
free -h
echo ""
echo "Swappiness: $(cat /proc/sys/vm/swappiness 2>/dev/null || echo 'n/a')"
echo ""
echo "vmstat (si/so columns = swap-in/swap-out per second; nonzero sustained values mean swap thrashing):"
vmstat 1 3 2>/dev/null || echo "(vmstat unavailable)"

# ---------------------------------------------------------------------------------------------------------------------
section "Disks"
lsblk -d -o NAME,SIZE,ROTA,MODEL 2>/dev/null || echo "(lsblk unavailable)"
echo "(ROTA=1 means spinning disk; journal-acknowledged writes are much more expensive on spinning disks)"
echo ""
df -h /var/lib/docker 2>/dev/null || df -h /
echo ""
if command -v iostat > /dev/null 2>&1; then
    echo "iostat -x (watch %util and r_await/w_await):"
    iostat -x 1 3
else
    echo "iostat not installed (apt install sysstat); using /proc/diskstats fallback"
    echo "Approx disk utilization % over 5s (per device):"
    awk '{print $3, $13}' /proc/diskstats > /tmp/.diag_disk_a
    sleep 5
    awk '{print $3, $13}' /proc/diskstats > /tmp/.diag_disk_b
    join /tmp/.diag_disk_a /tmp/.diag_disk_b 2>/dev/null | \
        awk '$1 !~ /^(loop|ram)/ { util = ($3 - $2) / 5000 * 100; if (util > 0.1) printf "  %-12s %6.1f%%\n", $1, util }'
    rm -f /tmp/.diag_disk_a /tmp/.diag_disk_b
fi

# ---------------------------------------------------------------------------------------------------------------------
section "Container states (restarts / OOM kills / limits)"
for c in "$MONGO_CONTAINER" "$DBSERVER_CONTAINER" "$AUDITPROC_CONTAINER" "$INTERCONNECT_CONTAINER"; do
    if have_container "$c"; then
        docker inspect --format \
'{{.Name}}
  Image:        {{.Config.Image}}
  StartedAt:    {{.State.StartedAt}}
  RestartCount: {{.RestartCount}}
  OOMKilled:    {{.State.OOMKilled}}
  MemoryLimit:  {{.HostConfig.Memory}}
  MemorySwap:   {{.HostConfig.MemorySwap}}' "$c"
    else
        echo "/$c: NOT FOUND (wrong prefix? pass it as the first argument)"
    fi
done
echo ""
echo "Note: RestartCount > 0 together with OOMKilled=true on mongo means the"
echo "MONGO_MEMORY_LIMIT is being hit; MemorySwap > MemoryLimit means the"
echo "container is allowed to swap before being killed (slow, not fatal)."
echo ""
echo "docker stats snapshot:"
docker stats --no-stream "$MONGO_CONTAINER" "$DBSERVER_CONTAINER" "$AUDITPROC_CONTAINER" "$INTERCONNECT_CONTAINER" 2>/dev/null

echo ""
echo "Kernel OOM events (needs root; empty is good):"
dmesg -T 2>/dev/null | grep -i -E "out of memory|oom-kill" | tail -n 10 || echo "(dmesg not accessible - rerun with sudo to check for OOM kills)"

# ---------------------------------------------------------------------------------------------------------------------
section "Mongo deployment configuration"
if have_container "$MONGO_CONTAINER"; then
    echo "mongod command line:"
    docker inspect --format '{{join .Config.Cmd " "}}' "$MONGO_CONTAINER"
    echo ""
    echo "Host RAM and what the WiredTiger cache would have been BEFORE the bounded-cache change"
    echo "(mongod default = 50% of (host RAM - 1GB)):"
    awk '/MemTotal/ { ram_gb = $2 / 1048576; printf "  Host RAM: %.1f GB -> old default cache: ~%.1f GB\n", ram_gb, (ram_gb - 1) / 2 }' /proc/meminfo
else
    echo "mongo container not found"
fi

if have_container "$DBSERVER_CONTAINER"; then
    echo ""
    echo "dbserver mongo-related environment (journal/direct default to true when unset):"
    docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$DBSERVER_CONTAINER" | grep -i "mongo" || echo "  (no MONGO_* overrides set)"
fi
if have_container "$INTERCONNECT_CONTAINER"; then
    echo ""
    echo "data_interconnector mongo-related environment:"
    docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$INTERCONNECT_CONTAINER" | grep -i "mongo" || echo "  (no PF_MONGO_* overrides set)"
fi

# ---------------------------------------------------------------------------------------------------------------------
section "Replica set + oplog state"
if have_container "$MONGO_CONTAINER"; then
    docker exec "$MONGO_CONTAINER" mongo --quiet --eval '
try {
    var st = rs.status();
    print("replSet state: " + st.myState + " (1 = PRIMARY = healthy)");
} catch (e) {
    print("replSet not active: " + e);
}
try {
    var local_db = db.getSiblingDB("local");
    var stats = local_db.oplog.rs.stats();
    print("oplog used: " + (stats.size / 1048576).toFixed(0) + " MB of max " + (stats.maxSize / 1048576).toFixed(0) + " MB");
    var first = local_db.oplog.rs.find().sort({$natural: 1}).limit(1).next().ts.t;
    var last = local_db.oplog.rs.find().sort({$natural: -1}).limit(1).next().ts.t;
    var window_hours = (last - first) / 3600;
    print("oplog window: " + window_hours.toFixed(1) + " hours");
    if (window_hours > 0.01) {
        print("approx write volume (oplog churn): " + (stats.size / 1048576 / window_hours).toFixed(1) + " MB/hour");
    }
} catch (e) {
    print("oplog stats unavailable: " + e);
}'
fi

# ---------------------------------------------------------------------------------------------------------------------
section "Mongo performance sample (${SAMPLE_SECONDS}s window - please wait)"
if have_container "$MONGO_CONTAINER"; then
    docker exec "$MONGO_CONTAINER" mongo --quiet --eval "var SAMPLE_MS = ${SAMPLE_SECONDS} * 1000;"'
var s1 = db.serverStatus();
sleep(SAMPLE_MS);
var s2 = db.serverStatus();
var dt = (s2.localTime - s1.localTime) / 1000;
print("interval: " + dt.toFixed(1) + "s");

print("");
print("--- Operation rates ---");
["insert", "query", "update", "delete", "command"].forEach(function (k) {
    print("  " + k + "/s: " + ((s2.opcounters[k] - s1.opcounters[k]) / dt).toFixed(1));
});

print("");
print("--- Mean operation latency over the window ---");
["reads", "writes", "commands"].forEach(function (k) {
    var d_lat = s2.opLatencies[k].latency - s1.opLatencies[k].latency;
    var d_ops = s2.opLatencies[k].ops - s1.opLatencies[k].ops;
    var mean_ms = d_ops > 0 ? (d_lat / d_ops / 1000).toFixed(2) : "n/a";
    print("  " + k + ": " + mean_ms + " ms/op  (" + (d_ops / dt).toFixed(1) + " ops/s)");
});
print("  (healthy writes on SSD are typically <2 ms/op; sustained >10 ms/op means the");
print("   journal fsyncs and/or disk are the bottleneck)");

print("");
print("--- WiredTiger cache ---");
var c1 = s1.wiredTiger.cache, c2 = s2.wiredTiger.cache;
print("  configured max: " + (c2["maximum bytes configured"] / 1073741824).toFixed(2) + " GB");
print("  currently used: " + (c2["bytes currently in the cache"] / 1073741824).toFixed(2) + " GB");
print("  dirty:          " + (c2["tracked dirty bytes in the cache"] / 1048576).toFixed(0) + " MB"
      + "  (eviction starts at 5% of cache, app threads throttle at 20%)");
var d_req = c2["pages requested from the cache"] - c1["pages requested from the cache"];
var d_read = c2["pages read into cache"] - c1["pages read into cache"];
print("  read into cache: " + ((c2["bytes read into cache"] - c1["bytes read into cache"]) / 1048576 / dt).toFixed(1) + " MB/s");
print("  cache miss ratio: " + (d_req > 0 ? (100 * d_read / d_req).toFixed(2) + " %" : "n/a")
      + "  (page reads / page requests; >2-5% sustained = cache too small for working set)");
["application threads page read from disk to cache count",
 "application threads page read from disk to cache time (usecs)",
 "application threads page write from cache to disk count",
 "application threads page write from cache to disk time (usecs)"].forEach(function (k) {
    if (c1.hasOwnProperty(k)) {
        print("  delta \"" + k + "\": " + (c2[k] - c1[k]));
    }
});
print("  (app-thread page read/write time = queries stalled doing cache eviction/IO themselves;");
print("   large deltas here are the signature of an undersized cache)");

print("");
print("--- Journal (write-ahead log) ---");
var l1 = s1.wiredTiger.log, l2 = s2.wiredTiger.log;
print("  log syncs/s: " + ((l2["log sync operations"] - l1["log sync operations"]) / dt).toFixed(1));
print("  time in log sync: " + ((l2["log sync time duration (usecs)"] - l1["log sync time duration (usecs)"]) / 1000 / dt).toFixed(1)
      + " ms per wall-clock second");
print("  log bytes written/s: " + ((l2["log bytes written"] - l1["log bytes written"]) / 1024 / dt).toFixed(0) + " KB/s");
print("  (high syncs/s with high time-in-sync = journal-acknowledged writes dominating the disk)");

print("");
print("--- Concurrency tickets ---");
print("  read tickets  out/available: " + s2.wiredTiger.concurrentTransactions.read.out + "/" + s2.wiredTiger.concurrentTransactions.read.available);
print("  write tickets out/available: " + s2.wiredTiger.concurrentTransactions.write.out + "/" + s2.wiredTiger.concurrentTransactions.write.available);
print("  (available near 0 = storage engine saturated)");

print("");
print("--- Memory / flow control ---");
print("  mongod resident: " + s2.mem.resident + " MB");
if (s2.flowControl) {
    print("  flowControl isLagged: " + s2.flowControl.isLagged + ", timeAcquiringMicros: " + s2.flowControl.timeAcquiringMicros);
}'
else
    echo "mongo container not found - skipping"
fi

# ---------------------------------------------------------------------------------------------------------------------
section "Slow queries in the last 24h (mongod --slowms 200)"
if have_container "$MONGO_CONTAINER"; then
    SLOW_LINES=$(docker logs --since 24h "$MONGO_CONTAINER" 2>&1 | grep -E "[0-9]+ms$")
    TOTAL_SLOW=$(echo "$SLOW_LINES" | grep -c . )
    echo "Total slow (>200ms) operations: ${TOTAL_SLOW}"
    echo "Slow COLLSCAN operations:       $(echo "$SLOW_LINES" | grep -c COLLSCAN)"
    echo ""
    echo "Busiest namespaces among slow ops:"
    echo "$SLOW_LINES" | awk '{for (i = 1; i <= NF; i++) if ($i == "command" || $i == "query" || $i == "insert" || $i == "update" || $i == "remove" || $i == "getmore") { print $(i + 1); break }}' \
        | sort | uniq -c | sort -rn | head -n 10
    echo ""
    echo "10 slowest operations (truncated):"
    echo "$SLOW_LINES" | awk '{ms = $NF; sub("ms$", "", ms); print ms + 0, substr($0, 1, 400)}' | sort -rn | head -n 10 | cut -d" " -f2-
else
    echo "mongo container not found - skipping"
fi

# ---------------------------------------------------------------------------------------------------------------------
section "Batch processing run history (service_audit_processing)"
if have_container "$AUDITPROC_CONTAINER"; then
    echo "Recent 'Processing complete' lines (durationMs = full pass over the report range):"
    docker logs --since 96h "$AUDITPROC_CONTAINER" 2>&1 | grep -E "Processing complete" | tail -n 30
    echo ""
    echo "Recent sleep lines (NO 'Sleeping' lines between runs = the service is not keeping up):"
    docker logs --since 96h "$AUDITPROC_CONTAINER" 2>&1 | grep -E "Sleeping" | tail -n 10
else
    echo "service_audit_processing container not found - skipping"
fi

section "Done"
echo "Report written to: ${REPORT_FILE}"
}

collect_report 2>&1 | tee "$REPORT_FILE"
