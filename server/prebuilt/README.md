# How to build

 * Download the sources for the nginx package used by the `phusion/passenger-ruby22` image.

   ```bash
   cd ~/passenger_shib
   dget -xu https://oss-binaries.phusionpassenger.com/apt/passenger/pool/xenial/main/n/nginx/nginx_1.12.2-8.5.2.3~xenial1.dsc
   ```

 * Clone the `nginx-http-shibboleth` repository.

   ```bash
   cd ~/passenger_shib
   git clone https://github.com/nginx-shib/nginx-http-shibboleth
   ```

 * Edit `~/passenger_shib/nginx-*/debian/rules`.

   * Add `--add-dynamic-module=$(HOME)/passenger_shib/nginx-http-shibboleth` to the `common_configure_flags` variable.

   * Add `-fPIC` to the `debian_cflags` variable.

   * Add `; exit 0` to the end of the line containing `quilt push -a`.

 * Build the package.

   ```bash
   cd ~/passenger_shib/nginx-*
   dpkg-buildpackage -j16
   ```

 * Find the library (`find -name ngx_http_shibboleth_module.so`) and copy it here.
