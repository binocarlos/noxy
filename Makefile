.PHONY=debug
debug:
	docker build -t binocarlos/noxy .
	docker run -ti --rm \
	  -e NOXY_PRODUCTS_FRONT=/products/v1 \
	  -e NOXY_PRODUCTS_HOST=products \
	  -e NOXY_PRODUCTS_BACK=/ \
	  -e NOXY_REVIEWS_FRONT=/reviews/v1 \
	  -e NOXY_REVIEWS_HOST=reviews \
	  -e NOXY_REVIEWS_PORT=8273 \
	  -e NOXY_REVIEWS_BACK=/custombackendpath \
	  -e NOXY_DEFAULT_HOST=webserver \
	  -e DEBUG=1 \
	  binocarlos/noxy