#!/bin/bash
set -e

SAVED_DIR="/data/saved"
SERVER_DIR="/data/server_files"
STEAMCMD_DIR="/data/steamcmd"

STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"

if [ ! -d "$SAVED_DIR" ]; then
    echo "Creating directory $SAVED_DIR..."
    mkdir "$SAVED_DIR"
fi
if [ ! -d "$SERVER_DIR" ]; then
    echo "Creating directory $SERVER_DIR..."
    mkdir "$SERVER_DIR"
fi
if [ ! -d "$STEAMCMD_DIR" ]; then
    echo "Creating directory $STEAMCMD_DIR..."
    mkdir "$STEAMCMD_DIR"
fi

if [ ! -d "$SERVER_DIR/ShooterGame" ]; then
    mkdir "$SERVER_DIR/ShooterGame"
fi
ln -snf "$SAVED_DIR" "$SERVER_DIR/ShooterGame/Saved"

if [ ! -f "$STEAMCMD_DIR/steamcmd.sh" ]; then
    echo "Installing SteamCMD..."
    cd "$STEAMCMD_DIR"
    curl -sqL "$STEAMCMD_URL" | tar zxf -
    if [ ! -f "$STEAMCMD_DIR/steamcmd.sh" ]; then
        echo "ERROR: Failed to install SteamCMD. Exiting..."
        exit 1
    fi
fi

if [ ! -f "$SERVER_DIR/ShooterGame/Binaries/Linux/ShooterGameServer" ] || [ "$UPDATE_SERVER" -eq 1 ]; then
    echo "Updating Server..."
    cd "$STEAMCMD_DIR"

    UPDATE_SCRIPT="$HOME/update_script.txt"
    echo "@ShutdownOnFailedCommand 1" > $UPDATE_SCRIPT
    echo "@NoPromptForPassword 1" >> $UPDATE_SCRIPT
    echo "force_install_dir $SERVER_DIR" >> $UPDATE_SCRIPT
    echo "login anonymous" >> $UPDATE_SCRIPT
    if [ -z "$SERVER_BRANCH" ]; then
        echo "app_update $SERVER_APPID" >> $UPDATE_SCRIPT
    else
        echo "app_update $SERVER_APPID -beta $SERVER_BRANCH" >> $UPDATE_SCRIPT
    fi
    echo "quit" >> $UPDATE_SCRIPT
    echo "--- SteamCMD Script ---"
    cat $UPDATE_SCRIPT
    echo "-----------------------"

    $STEAMCMD_DIR/steamcmd.sh +runscript "$UPDATE_SCRIPT"
    STEAM_EXIT=$?
    echo "SteamCMD exited with code $STEAM_EXIT"
    if [ ! -f "$SERVER_DIR/ShooterGame/Binaries/Linux/ShooterGameServer" ] || [ $STEAM_EXIT -ne 0 ]; then
        echo "ERROR: Failed to update server. Exiting..."
        exit 1
    fi
fi

players_connected()
{
    rcon_cmd='rcon -P'"${ADMIN_PASSWORD}"' -a127.0.0.1 -p27020'
    player_list="$(${rcon_cmd} listplayers)"
    if [ $? -ne 0 ]; then
        echo "[$(date -Iseconds)]: ERROR: RCON failed, listplayers."
        return 2
    fi
    player_list="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'<<<"$player_list")"
    if [ "$player_list" = "No Players Connected" ]; then
        return 1
    else
        return 0
    fi
}

wait_players_connected()
{
    while :
    do
        if players_connected; then
            return 0
        fi
        sleep 5
    done
}

wait_server_up()
{
    rcon_cmd='rcon -P'"${ADMIN_PASSWORD}"' -a127.0.0.1 -p27020'
    while :
    do
        if ${rcon_cmd} listplayers >/dev/null 2>&1; then
            return
        fi
        echo "[$(date -Iseconds)]: Server Is Loading..."
        sleep 5
    done
}
export -f players_connected
export -f wait_players_connected
export -f wait_server_up

empty_pause()
{
    # wait for server startup
    # TODO setup a "proxy" that will respond to server queries even when the server is stopped
    # https://developer.valvesoftware.com/wiki/Server_queries
    # This would no longer require filtering packets on 27015
    set +e
    sleep 2
    wait_server_up
    sleep 5
    echo "[$(date -Iseconds)]: Server Is Up."
    has_players=1
    tcpdump_cmd="sudo tcpdump -i any udp port 7777 or udp port 27015 -c 1"
    tcpdump_player_cmd="sudo tcpdump -i any udp port 7777 -c 1"
    rcon_cmd='rcon -P'"${ADMIN_PASSWORD}"' -a127.0.0.1 -p27020'
    while :
    do
        if [ "$has_players" -eq 0 ]; then
            $tcpdump_cmd >/dev/null 2>&1
            kill -CONT $server_pid
            echo "[$(date -Iseconds)]: Server Queried. Waiting for connection..."
            if timeout 30 bash -c "wait_players_connected"; then
                # player connected
                $rcon_cmd "slomo 1.0" >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                    echo "[$(date -Iseconds)]: ERROR: RCON failed, slomo 1.0."
                    sleep 10
                    continue
                fi
                has_players=1
                echo "[$(date -Iseconds)]: Player Connected. Resuming Server."
            else
                # player didnt connect
                kill -STOP $server_pid
                echo "[$(date -Iseconds)]: No Connections. Pausing Server."
            fi
        else
            if timeout 30 $tcpdump_player_cmd >/dev/null 2>&1; then
                # packets were sent/recv
                sleep 30
            else
                # no packets were sent/recv
                $rcon_cmd "slomo 0.05" >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                    echo "[$(date -Iseconds)]: ERROR: RCON failed, slomo 0.05."
                    sleep 10
                    continue
                fi
                has_players=0
                kill -STOP $server_pid
                echo "[$(date -Iseconds)]: All Players Left. Pausing Server."

            fi
        fi
    done
}

kill_all()
{
    echo "Stopping server PID $server_pid"
    kill -INT $server_pid

    echo "Stopping pauser PID $pauser_pid"
    kill -KILL $pauser_pid
    echo "Done."
}

trap kill_all INT TERM

cd "$SERVER_DIR/ShooterGame/Binaries/Linux"
if ! [ -z "$SERVER_PASSWORD" ]; then
    pw_arg='?ServerPassword='"$SERVER_PASSWORD"
fi
server_args=()
server_args+=( "$MAP_NAME"'?SessionName='"${SERVER_NAME}${pw_arg}"'?ServerAdminPassword='"$ADMIN_PASSWORD"'?Port=7777?QueryPort=27015?MaxPlayers='"$MAX_PLAYERS" )
server_args+=( "-server" "-log" "-nobattleye" )
echo "Starting Server..."
printf 'Server start args: [ '
printf '%s, ' "${server_args[@]}"
printf ' ]\n'
./ShooterGameServer "${server_args[@]}" -server -log -nobattleye &
server_pid=$!
empty_pause &
pauser_pid=$!
wait $server_pid
echo "Done."
