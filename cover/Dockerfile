# Dockerfile from
#
#     https://intercityup.com/blog/how-i-build-a-docker-image-for-my-rails-app.html
#
# See more documentation at the passenger-docker GitHub repo:
#
#     https://github.com/phusion/passenger-docker
#
#
FROM phusion/passenger-ruby22:0.9.30

MAINTAINER Autolab Development Team "autolab-dev@andrew.cmu.edu"

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Start Nginx / Passenger
RUN rm -f /etc/service/nginx/down
# Remove the default site
RUN rm /etc/nginx/sites-enabled/default
# Add the nginx info
ADD docker/nginx.conf /etc/nginx/sites-enabled/webapp.conf

# Prepare folders
RUN mkdir /home/app/webapp

# Add tzdata
RUN apt-get update && \
  apt-get install -y tzdata

# Run Bundle in a cache efficient way
WORKDIR /tmp
ADD Gemfile /tmp/
ADD Gemfile.lock /tmp/
RUN bundle install

# Add the rails app
ADD . /home/app/webapp

RUN mkdir -p /home/app/webapp/courses \
    /home/app/webapp/assessmentConfig \
    /home/app/webapp/courseConfig \
    /home/app/webapp/gradebooks \
    /home/app/webapp/tmp/cache

RUN chown -R app:app /home/app/webapp/courses \
    /home/app/webapp/assessmentConfig \
    /home/app/webapp/courseConfig \
    /home/app/webapp/gradebooks \
    /home/app/webapp/tmp



# Move the database configuration into place
ADD config/database.docker.yml /home/app/webapp/config/database.yml

# Create the log files
RUN mkdir -p /home/app/webapp/log && \
  touch /home/app/webapp/log/production.log && \
  chown -R app:app /home/app/webapp/log && \
  chmod 0664 /home/app/webapp/log/production.log

# precompile the Rails assets
WORKDIR /home/app/webapp
RUN RAILS_ENV=production bundle exec rake assets:precompile

# Let's Encrypt
RUN add-apt-repository ppa:certbot/certbot && \
  apt-get update && \
  apt-get install -y python-certbot-nginx && \
  certbot register --agree-tos -m root@autolab.ufscar.br

# Shibboleth
ADD docker/ngx_http_shibboleth_module.so /usr/lib/ngx_http_shibboleth_module.so

RUN apt-get install -y ca-certificates shibboleth-sp2-utils supervisor && \
  mkdir -p /var/log/shibboleth /var/run/shibboleth && \
  chown -R _shibd:_shibd /var/log/shibboleth /var/run/shibboleth && \
  echo "load_module /usr/lib/ngx_http_shibboleth_module.so;" > /etc/nginx/main.d/shib.conf

ADD docker/shib.conf /etc/supervisor/conf.d/shib.conf

ADD docker/attribute-map.xml /etc/shibboleth/attribute-map.xml
ADD docker/shibboleth2.xml /etc/shibboleth/shibboleth2.xml

ADD docker/sp-key.pem /etc/shibboleth/sp-key.pem
ADD docker/sp-cert.pem /etc/shibboleth/sp-cert.pem
RUN chown _shibd:_shibd /etc/shibboleth/*.pem && \
  chmod 0600 /etc/shibboleth/sp-key.pem && \
  chmod 0644 /etc/shibboleth/sp-cert.pem

RUN mkdir -p /etc/service/shibd && \
  echo '#!/bin/sh\nset -e\nexec /usr/bin/chpst -u _shibd:_shibd /usr/sbin/shibd -F -f -c /etc/shibboleth/shibboleth2.xml' > /etc/service/shibd/run && \
  chmod +x /etc/service/shibd/run && \
  mkdir -p /etc/service/supervisor && \
  echo '#!/bin/sh\nset -e\nexec /usr/bin/python /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf' > /etc/service/supervisor/run && \
  chmod +x /etc/service/supervisor/run

# MOSS
ADD docker/mossnet /home/app/webapp/vendor/

# UTF-8 Locale - https://stackoverflow.com/a/46531235
RUN export DEBIAN_FRONTEND=noninteractive; \
  apt-get update -q -q && \
  apt-get install --yes locales && \
  locale-gen --no-purge en_US.UTF-8 && \
  update-locale LANG=en_US.UTF-8 && \
  echo locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8 | debconf-set-selections && \
  echo locales locales/default_environment_locale select en_US.UTF-8 | debconf-set-selections && \
  dpkg-reconfigure locales
ENV LANG en_US.UTF-8

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
