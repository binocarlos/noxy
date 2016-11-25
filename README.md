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
      NOXY_DEFAULT_HOST: webserver
```

## usage

For each backend service you have - there are 3 env variables:
 
 * `NOXY_XXX_FRONT` - the incoming route to match (anything below this will also match)
 * `NOXY_XXX_HOST` - the hostname for the service
 * `NOXY_XXX_PORT` - the port for the service (default = 80)
 * `NOXY_XXX_BACK` - map the frontend route onto the backend route

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