function view_winboat {
    echo "Starting WinBoat container..."
    docker start WinBoat
    
    echo "Waiting for Windows to boot and RDP to be ready..."
    RDP_PORT=""
    
    # Wait for Windows to be ready and RDP port to be accessible
    for i in {1..90}; do
        if docker logs WinBoat 2>&1 | grep -q "Windows started successfully"; then
            # Detect the actual RDP port being used
            RDP_PORT=$(docker port WinBoat 3389/tcp | cut -d: -f2)
            
            if [ -n "$RDP_PORT" ]; then
                # Check if RDP port is accessible
                if timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/$RDP_PORT" 2>/dev/null; then
                    echo "Windows is ready and RDP is accepting connections on port $RDP_PORT!"
                    sleep 3  # Give RDP server a bit more time to be fully ready
                    break
                fi
            fi
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    if [ -z "$RDP_PORT" ]; then
        echo "Error: Could not detect RDP port. Container may not be running properly."
        return 1
    fi
    
    echo "Connecting via RDP to port $RDP_PORT..."

    WIN_PASS=$(grep --include="*.log" -R '/p:"' ~/.winboat | sed 's|.*/p:"||g' | sed 's|" /v.*||g' | head -n 1)
    
    sdl-freerdp /v:127.0.0.1:$RDP_PORT /u:$USER /p:"$WIN_PASS" /dynamic-resolution /cert:ignore /clipboard /network:auto
}