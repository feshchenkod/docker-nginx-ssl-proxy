# Differences from the main [repository](https://github.com/DanielDent/docker-nginx-ssl-proxy)
* Changed base image to alpine linux;
* Enabled gzip;
* Added brotli compression support;
* Added HTTP Basic Authentication credentials username `user`;
* Added support for for multiple domains (with same auth settings).


# SSL Front-End Proxy With Automatic Free Certificate Management

Zero configuration required - set up SSL in 30 seconds. Out of the box A rating at SSL labs. HTTP/2 enabled for increased performance.

This image contains nginx along with some glue code to automatically obtain and renew a free DV SSL certificate from [Let's Encrypt](https://letsencrypt.org/).

It is configured by setting two environment variables:
   * `UPSTREAM` - The IP address or hostname (and optional port) of the upstream server to proxy requests towards.
   * `SERVERNAME` - The hostname to listen to. The system will automatically obtain an SSL certificate for this hostname.

An optional `EXTRANAMES` variable can be provided with a list of additional domains to request as subject-alternative-names for the certificate.

Certificates from Let's Encrypt are issued with a 90 day expiration. This image will automatically renew the certificate when it is 60 days old.

Prior versions of this image used simp_le. It has been changed to use certbot due to reliability issues with simp_le.

## WARNING - HSTS Strict-Transport-Security Header

This image's default configuration includes a `Strict-Transport-Security` header with expiry set to 1 year. Visitors' browsers will cache this header and will refuse to connect except over SSL. Eventually, you may wish to have your domain included in browser [HSTS Preload](https://hstspreload.appspot.com/) lists.

This header can be customized with the `HSTS_HEADER` variable. If set to `skip`, no HSTS header will be used. If set to any other value, the value of the `HSTS_HEADER` variable will be used as the header's value. e.g. to prepare for HSTS preload, you could set `HSTS_HEADER` to `max-age=31536000; includeSubDomains; preload`.

## Example Use (via docker-compose)

Create a docker-compose.yml file as follows:

    nginx-ssl-proxy:
      image: ghcr.io/feshchenkod/nginx-ssl-proxy:latest
      restart: always
      environment:
        UPSTREAM: 127.0.0.1:8080
        SERVERNAME: test.example.com
        EXTRANAMES: www.test.example.com,test2.example.com
      ports:
        - "80:80"
        - "443:443"
      volumes:
        - "/etc/letsencrypt"

Then simply `docker-compose up`.

## Optional: Enable Simple Authentication

If the `DO_AUTH` environment variable is set to `required`, the proxy implements a simple authentication system.

A user meeting any of these three criteria will be allowed access to the proxied service:

   * Users coming from an IP or CIDR range listed in the space-separated `WHITELIST_IPS` variable.
   * Users presenting a cookie named `magic_ssl_proxy_auth` set to the value of the `COOKIE_VALUE` variable.
   * Users providing HTTP Basic Authentication credentials, username `admin` with a password matching the `PROXY_PASSWORD` variable and username `user` with a password matching the `USER_PASSWORD` variable.
   
A user that correctly authenticates with HTTP Basic Authentication will have their `magic_ssl_proxy_auth` cookie set so that they are not required to re-authenticate. 
   
By default, no IPs are whitelisted. When authentication is enabled, the `COOKIE_VALUE`, `PROXY_PASSWORD` and `USER_PASSWORD` values will be chosen randomly if they are not provided. If randomly chosen, the randomly chosen values will be output to the console during container startup. The `PROXY_PASSWORD` value will also be available in the `/tmp/proxy_password` file within the container, while the chosen `COOKIE_VALUE` will be available in the `/etc/nginx/auth_part1.conf` file. 

Nginx limits the length of your `COOKIE_VALUE` for performance reasons. If your `COOKIE_VALUE` is too long, nginx will refuse to start and will display errors relating to `server_names_hash_bucket_size` and `server_names_hash_max_size`. If you have difficulties, try decreasing the legnth of your cookie or add directives to your Nginx configuration to increase the maximum size.

## Optional: Use upstream `X-Forwarded-For` headers

When configuring IP based authentication, be mindful that upstream reverse proxies and your Docker configuration may result in an apparent source IP that does not match the client's true IP address. Directly exposing this image to the internet (e.g. via the `ports` directive as in the above example) will remove one source of potential problems with IP based authentication.

Set the `REAL_IP_RECURSIVE` environment variable to `on` to cause Nginx to parse & use upstream `X-Forwarded-For` headers.

The list of IPs or CIDR ranges from which Nginx will trust the `X-Forwarded-For` variable can be specified in the `SET_REAL_IP_FROM` variable.

As a convenience, setting `SET_REAL_IP_FROM_CLOUDFLARE` to `yes` will cause Cloudflare's reverse proxy source IP addresses to be appended to the provided `SET_REAL_IP_FROM` list.  

## Optional: Adjust request size limits & buffer size

The `NGINX_CLIENT_MAX_BODY_SIZE` and `NGINX_CLIENT_BODY_BUFFER_SIZE` variables can be used to set nginx's `client_max_body_size` and `client_body_buffer_size` directives. This is most commonly required when users are uploading files to the proxied service.

E.g. With `NGINX_CLIENT_MAX_BODY_SIZE` set to `100m`, nginx will allow a maximum body size of 100 megabytes. When requests are larger than `client_body_buffer_size`, nginx buffers the request using a temporary file. A larger `client_body_buffer_size` will use more memory, but will also reduce disk I/O. In many scenarios, a larger buffer size will result in increased performance. Different tradeoffs will be appropriate for different environments and use cases. 

## Optional: Add Arbitrary Nginx Config

The `/etc/nginx/main_location.conf` file provides a place to add arbitrary Nginx configuration directives to the main location block in the Nginx configuration file. The file is empty and can be safely overwritten in a downstream image or using a Docker volume.

## Certificate Data

A `/etc/letsencrypt` volume is used to maintain certificate data. An `account_key.json` file holds the key to your Let's Encrypt account - which provides a convenient way to revoke a certificate.
 
## Customizing

Nginx configuration can be customized by editing [proxy.conf](https://github.com/feshchenkod/docker-nginx-ssl-proxy/blob/master/proxy.conf) and placing a new copy of it at `/etc/nginx/conf.d/default.conf`.

Example `Dockerfile`:

    FROM feshchenkod/nginx-ssl-proxy
    COPY proxy.conf /etc/nginx/conf.d/default.conf

## Multiple domains

To use additional domains set vars `UPSTREAM_N` `SERVERNAME_N` where `N` can be `1..9` and mount [proxy_N.conf](https://github.com/feshchenkod/docker-nginx-ssl-proxy/blob/master/proxy_1.conf) (replace `_1` with numbers from `_2` to `_9` and specify each config in volumes)
```
- ./proxy_N.conf:/etc/nginx/conf.d/proxy_N.conf
```

Example:
```
nginx-ssl-proxy:
  image: ghcr.io/feshchenkod/nginx-ssl-proxy:latest
  restart: always
  environment:
    UPSTREAM: test-back-0:80
    SERVERNAME: test-0.example.com
    UPSTREAM_1: test-back-1:80
    SERVERNAME_1: test-1.example.com
    UPSTREAM_2: test-back-2:80
    SERVERNAME_2: test-2.example.com
  ports:
    - "80:80"
    - "443:443"
  links:
    - "test-back-0"
    - "test-back-1"
    - "test-back-2"
  volumes:
    - "./letsencrypt:/etc/letsencrypt"
    - ./proxy_1.conf:/etc/nginx/conf.d/proxy_1.conf
    - ./proxy_2.conf:/etc/nginx/conf.d/proxy_2.conf
```

## SSL Settings

Reasonable defaults have been chosen for SSL cipher suites using [Mozilla's Recommendations](https://wiki.mozilla.org/Security/Server_Side_TLS). Very old browsers (such as IE6) will be unable to connect with the default settings.

## Security Headers

Reasonable defaults have been chosen with an eye towards a configuration which is more secure by default. See https://www.owasp.org/index.php/List_of_useful_HTTP_headers for more information on the headers used. These headers can be disabled by setting the `SECURITY_HEADERS` variable to `skip`. If your upstream server is itself sending these headers, setting the `SECURITY_HEADERS` variable will avoid the presence of multiple instances of these headers in responses.

## Dependencies

   * [alpine](https://hub.docker.com/_/alpine/) - Alpine linux
   * [nginx](https://www.nginx.com/) - proxy server
   * [brotli](https://github.com/google/brotli) - Brotli compression format
   * [certbot](https://certbot.eff.org/) - for handling certificate creation & validation (+ some wrappers in this image)
   * [envplate](https://github.com/kreuzwerker/envplate) - for allowing use of environment variables in Nginx configuration
   * [s6-overlay](https://github.com/just-containers/s6-overlay) - for PID 1, process supervision, zombie reaping