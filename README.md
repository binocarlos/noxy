# noxy

A simple Docker container that uses nginx as a reverse proxy to some backend microservices.

Use as a replacement for k8s ingress for use in a docker-compose development stack.

## install

```bash
$ docker pull binocarlos/noxy
```

## example

Here is a docker-compose file that uses noxy to front 3 other services and serves static content from a local build folder.

```yaml
version: '2'
services:
  # some backend api servers
  products:
    build:
      context: ./products
  reviews:
    build:
      context: ./reviews
  webserver:
    build:
      context: ./webserver
  # the router config
  router:
    image: binocarlos/noxy
    links:
      - products:products
      - reviews:reviews
      - webserver:webserver
    environment:
      NOXY_PRODUCTS_FRONT: /products/v1
      NOXY_PRODUCTS_HOST: products
      NOXY_PRODUCTS_BACK: /
      NOXY_REVIEWS_FRONT: /reviews/v1
      NOXY_REVIEWS_HOST: reviews
      NOXY_REVIEWS_PORT: 8273
      NOXY_REVIEWS_BACK: /custombackendpath
      NOXY_REVIEWS_BASIC_AUTH_USERNAME: admin
      NOXY_REVIEWS_BASIC_AUTH_PASSWORD: apples
      # enable websockets for this virtual host
      NOXY_REVIEWS_WS: 1
      NOXY_DEFAULT_HOST: webserver
```

## usage

For each backend service you have - there are 4 env variables:
 
 * `NOXY_XXX_FRONT` - the incoming route to match (anything below this will also match)
 * `NOXY_XXX_HOST` - the hostname for the service
 * `NOXY_XXX_REDIRECT` - means all routes will get a 302 redirect to here
 * `NOXY_XXX_PORT` - the port for the service (default = 80)
 * `NOXY_XXX_BACK` - map the frontend route onto the backend route
 * `NOXY_XXX_WS` - enable websockets for this backend
 * `NOXY_XXX_BASIC_AUTH_USERNAME` - activate basic auth for this route using the given username
 * `NOXY_XXX_BASIC_AUTH_PASSWORD` - activate basic auth for this route using the given password

#### FRONT

The FRONT setting for a route matches the incoming request and will proxy if it matches.

For example a `GET /products/v1/1234` would match our `NOXY_PRODUCTS_FRONT` and the request would be proxied to the products service.

#### HOST

The `HOST` setting controls where to proxy matching requests to.

If the value starts with `env:` - for example `NOXY_PRODUCTS_HOST=env:PRODUCTS_SERVICE_HOST` - it means:

> set the `PRODUCTS` service hostname to the value of the `PRODUCTS_SERVICE_HOST` env var

This is useful if you are running something like Kubernetes where the backend service hostname is written into the env and you can only know it at runtime.

#### PORT

The `PORT` value controls the port for the backend service - this defaults to 80.

#### BACK (optional)

If you provide a BACK setting - the frontend setting will be replaced by it for the request to the backend service.  This is useful if the backend service has a different mount-point and you want to map requests from a public frontend url to a different backend url.

For example a `GET /reviews/v1/123` would result in a `GET /custombackendpath/123` to our reviews service.

If you don't provide a BACK option - the bnackend url will be the same as the incoming request.

#### WS (optional)

If this is set to a truthy value, the following headers will be added to the nginx location block:

```
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

#### REDIRECT (optional)

This changes the meaning of the virtual host entry from `proxy requests to this backend` to `redirect requests to this other host`.

The `HOST` property is used as the hostname for the server and the `REDIRECT` value is used as the target redirect.

For example - to redirect any incoming request for `abc.com` to `xyz.con`:

```
NOXY_ABC_HOST: abc.com
NOXY_ABC_REDIRECT: http://xyz.com
```

You **must** include `http://` or `https://` in the redirect value - this lets you use noxy as a HTTPS redirector.

#### BASIC_AUTH_{USERNAME,PASSWORD} (optional)

Providing both of these values for a group will activate basic authentication for the route

#### NOXY_DEFAULT_HOST

You **must** provide a `NOXY_DEFAULT_HOST` setting - this is the service to which requests that do not match any other service will be routed.

The `FRONT` and `BACK` settings are ignored - it is usually the case you use your static webserver as the default route.


## debug

To get a printout of the nginx config noxy is creating:

```
$ make debug
```

## license

MIT