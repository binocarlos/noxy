#!/bin/bash -e

set -e

UPSTREAM_TEMP_FILE="/tmp/noxy_upstreams"
SERVER_TEMP_FILE="/tmp/noxy_servers"
REDIRECT_TEMP_FILE="/tmp/noxy_redirects"

echo '' > ${UPSTREAM_TEMP_FILE}
echo '' > ${SERVER_TEMP_FILE}
echo '' > ${REDIRECT_TEMP_FILE}

# NOXY_PRODUCTS_HOST -> PRODUCTS
function extract_servicename() {
  echo $@ | sed -E "s/^NOXY_(.+)_.+$/\1/"
}

# 1=PRODUCTS 2=HOST - return $NOXY_PRODUCTS_HOST
function get_service_var() {
  eval 'echo ${NOXY_'$1'_'$2'}'
}

function get_proxy_config() {
  cat<<end-of-proxy-config
      proxy_redirect     off;
      proxy_set_header Connection '';
      proxy_http_version 1.1;
      chunked_transfer_encoding off;
      client_max_body_size 0;
      proxy_buffering off;
      proxy_cache off;
      proxy_set_header   Host \$host;
      proxy_set_header   X-Real-IP \$remote_addr;
      proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Host \$server_name;
end-of-proxy-config
}

function get_ws_config() {
  local ws="$1"
  if [ -n "${ws}" ]; then
    cat<<end-of-ws-config
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
end-of-ws-config
  fi
}

# append to the temp file for the backends section
function add_upstream_def() {
  local service="$1"
  local server="$2"

  cat<<end-of-upstream-config >> ${UPSTREAM_TEMP_FILE}
  upstream ${service}_servers {
    server ${server};
  }

end-of-upstream-config
}

# /api/v1/x -> /api/v1/x
function add_normal_server_def() {
  local service="$1"
  local front="$2"
  local ws="$3"
  local proxyConfig=$(get_proxy_config)
  local wsConfig=$(get_ws_config "${ws}")

  cat<<end-of-server-config >> ${SERVER_TEMP_FILE}
    location $front {

      proxy_pass         http://${service}_servers;
      ${proxyConfig}
      ${wsConfig}

    }

end-of-server-config
}

# /api/v1/x -> /someother/x
function add_mapped_server_def() {
  local service="$1"
  local front="$2"
  local back="$3"
  local ws="$4"
  local proxyConfig=$(get_proxy_config)
  local wsConfig=$(get_ws_config "${ws}")

  # remove trailing slashes
  front=$(echo "${front}" | sed -E "s/\/$//")
  back=$(echo "${back}" | sed -E "s/\/$//")

  cat<<end-of-server-config >> ${SERVER_TEMP_FILE}
    location ${front}/ {

      proxy_pass         http://${service}_servers${back}/;
      ${proxyConfig}
      ${wsConfig}

    }

end-of-server-config
}

# abc.com/something/else.html -> xyz.com/something/else.html
function add_redirect_server_def() {
  local service="$1"
  local host="$2"
  local redirect="$3"

  cat<<end-of-redirect-config >> ${REDIRECT_TEMP_FILE}
    server {
        listen        80;
        server_name ${host};
        return 301 ${redirect}\$request_uri;
    }

end-of-redirect-config
}

function process_service() {
  local service="$1"
  local host=$(get_service_var $service HOST)
  local front=$(get_service_var $service FRONT)
  local back=$(get_service_var $service BACK)
  local port=$(get_service_var $service PORT)
  local ws=$(get_service_var $service WS)
  local redirect=$(get_service_var $service REDIRECT)
  

  if [ -n "${DEBUG}" ]; then
    echo "service $service - $server"
    echo "  host: $host"
    echo "  port: $port"
    echo "  front: $front"
    echo "  back: $back"
    echo "  ws: $ws"
    echo "  redirect: $redirect"
  fi

  if [ -n "${redirect}" ]; then
    add_redirect_server_def "${service}" "${host}" "${redirect}"
    return
  fi

  if [ -z "${port}" ]; then port=80; fi
  if [ "${service}" == "DEFAULT" ]; then
    front="/"
  else
    if [ -z "${front}" ]; then
      echo >&2 "You must give a FRONTEND for the ${service} service"
      exit 1
    fi
  fi

  local server="${host}:${port}"


  add_upstream_def "${service}" "${server}"

  if [ -n "${back}" ]; then
    add_mapped_server_def "${service}" "${front}" "${back}" "${ws}"
  else
    add_normal_server_def "${service}" "${front}" "${ws}"
  fi    
}

# ensure we have a default host
#function check_vars() {
  #if [ -z "${NOXY_DEFAULT_HOST}" ]; then
  #  echo >&2 "NOXY_DEFAULT_HOST var required"
  #  exit 1
  #fi
#}

# loop over the env
function process_vars() {
  for i in $( printenv ); do
    process_var $i
  done
}

# process a single var
function process_var() {
  local i="$1"
  if [[ "$i" =~ ^NOXY_[A-Z_]+_HOST ]]; then
    local service=$(extract_servicename $i)
    process_service $service
  fi
}

function write_nginx_config() {
  local upstream_defs=$(cat ${UPSTREAM_TEMP_FILE})
  local server_defs=$(cat ${SERVER_TEMP_FILE})
  local redirect_defs=$(cat ${REDIRECT_TEMP_FILE})

  rm ${UPSTREAM_TEMP_FILE} ${SERVER_TEMP_FILE} ${REDIRECT_TEMP_FILE}
  cat<<end-of-nginx-config > /etc/nginx/nginx.conf
worker_processes 1;
daemon off;
events { worker_connections 1024; }

http {

  sendfile on;

  gzip              on;
  gzip_http_version 1.0;
  gzip_proxied      any;
  gzip_min_length   500;
  gzip_disable      "MSIE [1-6]\.";
  gzip_types        text/plain text/xml text/css
                    text/comma-separated-values
                    text/javascript
                    application/x-javascript
                    application/atom+xml;

  ${upstream_defs}

  ${redirect_defs}

  server {
      
    listen 80;

    ${server_defs}
  }

  
}
end-of-nginx-config
}

function main() {
  #check_vars
  process_vars
  write_nginx_config

  if [ -z "${DEBUG}" ]; then
    nginx
  else
    cat /etc/nginx/nginx.conf
  fi
}

main