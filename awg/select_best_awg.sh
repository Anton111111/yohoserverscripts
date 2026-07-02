#!/bin/bash

# --- SETTINGS ---
CONFIGS_DIR="/home/anton/awg_configs"
INTERFACE_NAME="awg-best"
TMP_CONF="/etc/amnezia/amneziawg/${INTERFACE_NAME}.conf"
PING_ATTEMPTS=5
HANDSHAKE_TIMEOUT=5 # Max seconds to wait for handshake

# Target IPs for latency testing (Frankfurt, Ireland, London, Stockholm)
TARGETS=(
    "3.120.0.0"
    "52.208.0.0"
    "35.176.0.0"
    "13.48.0.0"
    "ec2.eu-central-1.amazonaws.com"
    "ec2.eu-west-1.amazonaws.com"
    "ec2.eu-west-2.amazonaws.com"
    "ec2.eu-north-1.amazonaws.com"
)
TARGET_PORT="443"

# --- COLOR CODES ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0;m' # No Color

# Ensure root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Please run this script as root (sudo).${NC}"
    exit 1
fi

# Cleanup function on exit or interrupt
cleanup() {
    echo -e "\n${YELLOW}Cleaning up and exiting...${NC}"
    awg-quick down "$INTERFACE_NAME" >/dev/null 2>&1
    rm -f "$TMP_CONF"
    exit ${1:-0}
}

# Trap Ctrl+C (SIGINT) and SIGTERM
trap 'cleanup 130' SIGINT SIGTERM

cd "$CONFIGS_DIR" || { echo -e "${RED}Error: Directory $CONFIGS_DIR not found.${NC}"; exit 1; }

# Check if there are any .conf files
shopt -s nullglob
configs=(*.conf)
if [ ${#configs[@]} -eq 0 ]; then
    echo -e "${RED}Error: No .conf files found in $CONFIGS_DIR${NC}"
    exit 1
fi

declare -A RESULTS_MEDIAN
declare -A RESULTS_AVERAGE

echo -e "${BLUE}Starting AWG configuration benchmark...${NC}"
echo "------------------------------------------------------------------"

for config in "${configs[@]}"; do
    echo -e "${YELLOW}Testing configuration: ${BLUE}$config${NC}"

    # Setup temporary configuration
    cp "$config" "$TMP_CONF"

    # Try to bring up the tunnel
    if ! awg-quick up "$INTERFACE_NAME" >/dev/null 2>&1; then
        echo -e "${RED}  [!] Failed to bring up interface $INTERFACE_NAME${NC}"
        rm -f "$TMP_CONF"
        continue
    fi

    # Wait for handshake dynamically
    echo -n "  [*] Waiting for tunnel handshake... "
    tunnel_ready=false
    for ((i=1; i<=HANDSHAKE_TIMEOUT; i++)); do
        if awg show "$INTERFACE_NAME" transfer >/dev/null 2>&1; then
            tunnel_ready=true
            break
        fi
        sleep 1
    done

    if [ "$tunnel_ready" = false ]; then
        echo -e "${RED}Timeout! No active handshake.${NC}"
        awg-quick down "$INTERFACE_NAME" >/dev/null 2>&1
        rm -f "$TMP_CONF"
        continue
    fi
    echo -e "${GREEN}Ready.${NC}"

    config_total_latency=0
    config_valid_targets=0

    # Test each target IP from the array
    for target_ip in "${TARGETS[@]}"; do
        echo -n "  [*] Benchmarking target $target_ip... "

        latencies=()
        for ((attempt=1; attempt<=PING_ATTEMPTS; attempt++)); do
            start_time=$(date +%s%N)
            nc -w 2 -z "$target_ip" "$TARGET_PORT" >/dev/null 2>&1
            exit_code=$?
            end_time=$(date +%s%N)

            if [ $exit_code -eq 0 ]; then
                duration=$(( (end_time - start_time) / 1000000 ))
                latencies+=($duration)
            else
                latencies+=(-1)
            fi
            sleep 0.1
        done

        # Filter out failed attempts
        valid_latencies=()
        for l in "${latencies[@]}"; do
            if [ "$l" -ne -1 ]; then
                valid_latencies+=($l)
            fi
        done

        if [ ${#valid_latencies[@]} -eq 0 ]; then
            echo -e "${RED}Unreachable${NC}"
            continue
        fi

        # Sort latencies to find the median
        IFS=$'\n' sorted_latencies=($(sort -n <<<"${valid_latencies[*]}"))
        unset IFS

        count=${#sorted_latencies[@]}
        if (( count % 2 == 1 )); then
            median=${sorted_latencies[$((count / 2))]}
        else
            low=${sorted_latencies[$((count / 2 - 1))]}
            high=${sorted_latencies[$((count / 2))]}
            median=$(( (low + high) / 2 ))
        fi

        # Calculate sum and average for this target
        target_sum=0
        for l in "${valid_latencies[@]}"; do
            target_sum=$((target_sum + l))
        done
        target_avg=$((target_sum / count))

        echo -e "${GREEN}Success (Median: ${median}ms, Avg: ${target_avg}ms)${NC}"

        # Clean IP string for associative array keys (remove dots)
        clean_ip="${target_ip//./_}"
        RESULTS_MEDIAN["${config}_${clean_ip}"]=$median
        config_total_latency=$((config_total_latency + target_avg))
        ((config_valid_targets++))
    done

    # Clean up the interface immediately after tests for this config
    awg-quick down "$INTERFACE_NAME" >/dev/null 2>&1
    rm -f "$TMP_CONF"

    # Calculate overall average if at least one target responded
    if [ "$config_valid_targets" -gt 0 ]; then
        config_overall_avg=$((config_total_latency / config_valid_targets))
        RESULTS_AVERAGE["$config"]=$config_overall_avg
    else
        echo -e "${RED}  [!] Configuration $config couldn't reach any targets.${NC}"
    fi

    echo "------------------------------------------------------------------"
done

# --- PRINT FINAL SORTED RESULTS ---
echo -e "\n${GREEN}=== BENCHMARK RESULTS (Sorted by Overall Average) ===${NC}"

# Sort configs by overall average latency (ascending)
for config in "${!RESULTS_AVERAGE[@]}"; do
    echo "$config:${RESULTS_AVERAGE[$config]}"
done | sort -t: -k2 -n | while IFS=: read -r config overall_avg; do

    # Collect medians for all targets into a single string
    medians_list=""
    for target_ip in "${TARGETS[@]}"; do
        clean_ip="${target_ip//./_}"
        key="${config}_${clean_ip}"
        
        if [[ -n "${RESULTS_MEDIAN[$key]}" ]]; then
            medians_list+="${RESULTS_MEDIAN[$key]}ms, "
        else
            medians_list+="N/A, "
        fi
    done
    # Strip the trailing comma and space
    medians_list="${medians_list%, }"

    # Print clean list entry
    echo -e "Config: ${BLUE}$config${NC} | Medians: [$medians_list] | Overall Avg: ${GREEN}${overall_avg}ms${NC}"
done
