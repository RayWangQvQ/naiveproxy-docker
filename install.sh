#!/usr/bin/env bash
set -e
set -u
set -o pipefail

host=""
mail=""
user=""
pwd=""
fakeHost="https://demo.cloudreve.org"
verbose=false

invocation='say_verbose "Calling: ${yellow:-}${FUNCNAME[0]} ${green:-}$*${normal:-}"'
exec 3>&1
if [ -t 1 ] && command -v tput >/dev/null; then
    # see if it supports colors
    ncolors=$(tput colors || echo 0)
    if [ -n "$ncolors" ] && [ $ncolors -ge 8 ]; then
        bold="$(tput bold || echo)"
        normal="$(tput sgr0 || echo)"
        black="$(tput setaf 0 || echo)"
        red="$(tput setaf 1 || echo)"
        green="$(tput setaf 2 || echo)"
        yellow="$(tput setaf 3 || echo)"
        blue="$(tput setaf 4 || echo)"
        magenta="$(tput setaf 5 || echo)"
        cyan="$(tput setaf 6 || echo)"
        white="$(tput setaf 7 || echo)"
    fi
fi

say_warning() {
    printf "%b\n" "${yellow:-}naiveproxy_docker_install: Warning: $1${normal:-}" >&3
}

say_err() {
    printf "%b\n" "${red:-}naiveproxy_docker_install: Error: $1${normal:-}" >&2
}

say() {
    # using stream 3 (defined in the beginning) to not interfere with stdout of functions
    # which may be used as return value
    printf "%b\n" "${cyan:-}naiveproxy_docker_install:${normal:-} $1" >&3
}

say_verbose() {
    if [ "$verbose" = true ]; then
        say "$1"
    fi
}

machine_has() {
    eval $invocation

    command -v "$1" >/dev/null 2>&1
    return $?
}

if machine_has "docker"; then
    docker --version
else
    say_err "Missing dependency: docker was not found."
    exit 1
fi

while [ $# -ne 0 ]; do
    name="$1"
    case "$name" in
    -t | --host | -[Hh]ost)
        shift
        host="$1"
        ;;
    -m | --mail | -[Mm]ail)
        shift
        mail="$1"
        ;;
    -u | --user | -[Uu]ser)
        shift
        user="$1"
        ;;
    -p | --pwd | -[Pp]wd)
        shift
        pwd="$1"
        ;;
    -f | --fake-host | -[Ff]ake[Hh]ost)
        shift
        fakeHost="$1"
        ;;
    --verbose | -[Vv]erbose)
        verbose=true
        ;;
    -? | --? | -h | --help | -[Hh]elp)
        script_name="$(basename "$0")"
        echo "Ray Naiveproxy in Docker"
        echo "Usage: $script_name [-t|--host <HOST>] [-m|--mail <MAIL>]"
        echo "       $script_name -h|-?|--help"
        echo ""
        echo "$script_name is a simple command line interface to install naiveproxy in docker."
        echo ""
        echo "Options:"
        echo "  -t,--host <HOST>         Your host, Defaults to \`$host\`."
        echo "      -Host"
        echo "          Possible values:"
        echo "          - xui.test.com"
        echo "  -m,--mail <MAIL>         Your mail, Defaults to \`$mail\`."
        echo "      -Mail"
        echo "          Possible values:"
        echo "          - mail@qq.com"
        echo "  -u,--user <USER>         Your proxy user name, Defaults to \`$user\`."
        echo "      -User"
        echo "          Possible values:"
        echo "          - user"
        echo "  -p,--pwd <PWD>         Your proxy password, Defaults to \`$pwd\`."
        echo "      -Pwd"
        echo "          Possible values:"
        echo "          - 1qaz@wsx"
        echo "  -f,--fake-host <FAKEHOST>         Your fake host, Defaults to \`$fakeHost\`."
        echo "      -FakeHost"
        echo "          Possible values:"
        echo "          - https://demo.cloudreve.org"
        echo "  -?,--?,-h,--help,-Help             Shows this help message"
        echo ""
        exit 0
        ;;
    *)
        say_err "Unknown argument \`$name\`"
        exit 1
        ;;
    esac
    shift
done

echo ""

if [ -z "$host" ]; then
    read -p "input your host(such as demo.test.tk):" host
else
    echo "host: $host"
fi

if [ -z "$mail" ]; then
    read -p "input your mail(such as test@qq.com):" mail
else
    echo "mail: $mail"
fi

if [ -z "$user" ]; then
    read -p "input your proxy user name(such as zhangsan):" user
else
    echo "user: $user"
fi

if [ -z "$pwd" ]; then
    read -p "input your proxy password(such as 1qaz@wsx):" pwd
else
    echo "pwd: $pwd"
fi

echo "fakeHost: $fakeHost"
echo ""
# args:
# remote_path - $1
get_http_header_curl() {
    eval $invocation
    local remote_path="$1"

    curl_options="-I -sSL --retry 5 --retry-delay 2 --connect-timeout 15 "
    curl $curl_options "$remote_path" 2>&1 || return 1
    return 0
}

# args:
# remote_path - $1
get_http_header_wget() {
    eval $invocation
    local remote_path="$1"
    local wget_options="-q -S --spider --tries 5 "
    # Store options that aren't supported on all wget implementations separately.
    local wget_options_extra="--waitretry 2 --connect-timeout 15 "
    local wget_result=''

    wget $wget_options $wget_options_extra "$remote_path" 2>&1
    wget_result=$?

    if [[ $wget_result == 2 ]]; then
        # Parsing of the command has failed. Exclude potentially unrecognized options and retry.
        wget $wget_options "$remote_path" 2>&1
        return $?
    fi

    return $wget_result
}

# Updates global variables $http_code and $download_error_msg
downloadcurl() {
    eval $invocation
    unset http_code
    unset download_error_msg
    local remote_path="$1"
    local out_path="${2:-}"
    local remote_path_with_credential="${remote_path}"
    local curl_options="--retry 20 --retry-delay 2 --connect-timeout 15 -sSL -f --create-dirs "
    local failed=false
    if [ -z "$out_path" ]; then
        curl $curl_options "$remote_path_with_credential" 2>&1 || failed=true
    else
        curl $curl_options -o "$out_path" "$remote_path_with_credential" 2>&1 || failed=true
    fi
    if [ "$failed" = true ]; then
        local response=$(get_http_header_curl $remote_path)
        http_code=$(echo "$response" | awk '/^HTTP/{print $2}' | tail -1)
        download_error_msg="Unable to download $remote_path."
        if [[ $http_code != 2* ]]; then
            download_error_msg+=" Returned HTTP status code: $http_code."
        fi
        say_verbose "$download_error_msg"
        return 1
    fi
    return 0
}

# Updates global variables $http_code and $download_error_msg
downloadwget() {
    eval $invocation
    unset http_code
    unset download_error_msg
    local remote_path="$1"
    local out_path="${2:-}"
    local remote_path_with_credential="${remote_path}"
    local wget_options="--tries 20 "
    # Store options that aren't supported on all wget implementations separately.
    local wget_options_extra="--waitretry 2 --connect-timeout 15 "
    local wget_result=''

    if [ -z "$out_path" ]; then
        wget -q $wget_options $wget_options_extra -O - "$remote_path_with_credential" 2>&1
        wget_result=$?
    else
        wget $wget_options $wget_options_extra -O "$out_path" "$remote_path_with_credential" 2>&1
        wget_result=$?
    fi

    if [[ $wget_result == 2 ]]; then
        # Parsing of the command has failed. Exclude potentially unrecognized options and retry.
        if [ -z "$out_path" ]; then
            wget -q $wget_options -O - "$remote_path_with_credential" 2>&1
            wget_result=$?
        else
            wget $wget_options -O "$out_path" "$remote_path_with_credential" 2>&1
            wget_result=$?
        fi
    fi

    if [[ $wget_result != 0 ]]; then
        local disable_feed_credential=false
        local response=$(get_http_header_wget $remote_path $disable_feed_credential)
        http_code=$(echo "$response" | awk '/^  HTTP/{print $2}' | tail -1)
        download_error_msg="Unable to download $remote_path."
        if [[ $http_code != 2* ]]; then
            download_error_msg+=" Returned HTTP status code: $http_code."
        fi
        say_verbose "$download_error_msg"
        return 1
    fi

    return 0
}

# args:
# remote_path - $1
# [out_path] - $2 - stdout if not provided
download() {
    eval $invocation

    local remote_path="$1"
    local out_path="${2:-}"

    if [[ "$remote_path" != "http"* ]]; then
        cp "$remote_path" "$out_path"
        return $?
    fi

    local failed=false
    local attempts=0
    while [ $attempts -lt 3 ]; do
        attempts=$((attempts + 1))
        failed=false
        if machine_has "curl"; then
            downloadcurl "$remote_path" "$out_path" || failed=true
        elif machine_has "wget"; then
            downloadwget "$remote_path" "$out_path" || failed=true
        else
            say_err "Missing dependency: neither curl nor wget was found."
            exit 1
        fi

        if [ "$failed" = false ] || [ $attempts -ge 3 ] || { [ ! -z $http_code ] && [ $http_code = "404" ]; }; then
            break
        fi

        say "Download attempt #$attempts has failed: $http_code $download_error_msg"
        say "Attempt #$((attempts + 1)) will start in $((attempts * 10)) seconds."
        sleep $((attempts * 10))
    done

    if [ "$failed" = true ]; then
        say_verbose "Download failed: $remote_path"
        return 1
    fi
    return 0
}

# 下载docker-compose文件
downloadDockerComposeFile() {
    eval $invocation
    rm -rf ./docker-compose.yml
    download https://raw.githubusercontent.com/RayWangQvQ/naiveproxy-docker/main/docker-compose.yml docker-compose.yml
    cat ./docker-compose.yml
}

downloadDataFiles() {
    eval $invocation
    mkdir -p ./data

    # entry
    rm -rf ./data/entry.sh
    download https://raw.githubusercontent.com/RayWangQvQ/naiveproxy-docker/main/data/entry.sh ./data/entry.sh

    # Caddyfile
    rm -rf ./data/Caddyfile
    download https://raw.githubusercontent.com/RayWangQvQ/naiveproxy-docker/main/data/Caddyfile ./data/Caddyfile
}

replaceCaddyfileConfigs() {
    eval $invocation

    # replace host
    sed -i 's|<host>|'"$host"'|g' ./data/Caddyfile

    # replace mail
    sed -i 's|<mail>|'"$mail"'|g' ./data/Caddyfile

    # replace user
    sed -i 's|<user>|'"$user"'|g' ./data/Caddyfile

    # replace pwd
    sed -i 's|<pwd>|'"$pwd"'|g' ./data/Caddyfile

    # replace fakeHost
    sed -i 's|<fakeHost>|'"$fakeHost"'|g' ./data/Caddyfile

    cat ./data/Caddyfile
}

downloadDockerComposeFile
echo ""
downloadDataFiles
echo ""
replaceCaddyfileConfigs
echo ""

{
    docker compose version && docker compose up -d
} || {
    docker-compose version && docker-compose up -d
} || {
    docker run -itd --name naiveproxy -p 80:80 -p 443:443 -v $PWD/data:/data -v $PWD/share:/root/.local/share zai7lou/naiveproxy-docker bash /data/entry.sh
}

echo "Successfully created container"
docker ps --filter "name=naiveproxy"
echo ""
echo ""

# docker logs -f naiveproxy | sed '/certificate obtained successfully/Q'
# docker logs -f naiveproxy | sed '/certificate obtained successfully/Q;echo "success"'

# docker logs -f naiveproxy | while read line; do
#     echo $line
#     if echo "$line" | grep -q "certificate obtained successfully"; then
#         exit 1
#     fi
# done

docker logs -f naiveproxy | while read line; do
    echo $line
    if echo "$line" | grep -q "certificate obtained successfully"; then
        echo ""
        echo "Congratulations! Deploy Successfully."
        echo "Next I'll try to turn off the log tracing process, or you can Ctrl+C to close it manually."
        echo "Then you can connect the proxy using you client~~"
        echo ""
        ps -ef | grep "logs -f naiveproxy" | grep -v "grep" | awk '{print $2}' | xargs kill -9
    fi
done

echo "finish"