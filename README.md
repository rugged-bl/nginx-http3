# Nginx with HTTP/3 (QUIC) and Brotli Support
This repository provides a Dockerized setup of Nginx configured with HTTP/3 (QUIC) and Brotli compression, utilizing custom build of OpenSSL 3.4.0 for QUIC support.
This repository is the result of enthusiastic research, feel free to use it's code.

# Features
* HTTP/3 (QUIC) support with OpenSSL 3.4.0.
* Brotli compression.
* Minimalistic configuration: just a streamlined Nginx setup, customizable via Docker.

# Usage

You can either fork the provided Dockerfile to build a custom image with additional modules or use the prebuilt image:

`docker pull ruggedbl/nginx-http3:latest`

# Important Notes
* Integrating BoringSSL with modern Nginx versions is challenging. This setup uses OpenSSL 3.4.0 for QUIC support.
* The `quic reuseport parameter should be specified in only one `listen` directive per unique IP address and port combination.
* It's possible to speed Up HTTP/3 negotiation by configuring HTTPS (SVCB) DNS records as detailed by Cloudflare https://blog.cloudflare.com/speeding-up-https-and-http-3-negotiation-with-dns/.

# Contributing
Feel free to file issues or ask questions.

# Helpful links
* https://www.f5.com/company/blog/nginx/quic-http3-support-openssl-nginx (States that OpenSSL 3.4.0 plans to support QUIC)
* https://blog.cloudflare.com/speeding-up-https-and-http-3-negotiation-with-dns/ (Speed Up HTTP/3 negotiation by configuring HTTPS (SVCB) DNS records)
* https://github.com/macbre/docker-nginx-http3/blob/v1.27.3/Dockerfile (As a way to configure "fat" nginx with HTTP/3, hopefully it works, but Alpine's built-in OpenSSL is older than 3.4.x)
* https://nginx.org/en/docs/quic.html (Building from sources seems outdated though)
