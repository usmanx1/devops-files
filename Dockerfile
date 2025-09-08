# Stage 1: Build the Angular application
FROM 323500295462.dkr.ecr.us-east-2.amazonaws.com/base-image:frontend-build-stage-22.04 AS build-stage

# Set working directory for Angular project
WORKDIR /app

# Copy application files
COPY . . 
WORKDIR /app/aithentic

# Restrict Angular/Node resource usage
ENV NG_BUILD_MAX_WORKERS=1
ENV NODE_OPTIONS="--max-old-space-size=6144"

# Install Angular dependencies, build the project, and handle Sentry sourcemaps
RUN npm install --save @sentry/angular --force \
    && npm install --force \
    && npm run build-${env} \
    && mkdir -p ./dist/aithentic/sw-backup \
    && cp ./dist/aithentic/*worker*.js ./dist/aithentic/sw-backup/ \
    && npm run sentry:sourcemaps-${env} \
    && find ./dist/aithentic/ -type f -name "*.map" -delete \
    && cp ./dist/aithentic/sw-backup/* ./dist/aithentic/ \
    && node regenerate-hashes.js \
	&& rm -rf ./dist/aithentic/sw-backup
	
	

# Stage 2: Set up Apache and deploy the built Angular application
FROM 323500295462.dkr.ecr.us-east-2.amazonaws.com/base-image:frontend-22.04

# Copy Apache configurations
COPY apache2/apache2.conf /etc/apache2/apache2.conf
COPY apache2/envvars /etc/apache2/envvars
COPY apache2/ports.conf /etc/apache2/ports.conf
COPY apache2/sites-available/aithentic-front.conf /etc/apache2/sites-available/aithentic-front.conf
COPY apache2/sites-available/aithentic-front-le-ssl.conf /etc/apache2/sites-available/aithentic-front-le-ssl.conf

# Set working directory for the final deployment
WORKDIR /var/www/aithentic-front-end

# Copy built Angular files from the build stage
COPY --from=build-stage /app/aithentic/dist/* /var/www/aithentic-front-end/
COPY --from=build-stage /app/aithentic/htaccess/.htaccess /var/www/aithentic-front-end/

# Enable Apache sites and modules
RUN a2dissite 000-default.conf default-ssl.conf \
    && a2ensite aithentic-front.conf aithentic-front-le-ssl.conf \
    && a2enmod rewrite ssl headers

# Expose port
EXPOSE 8083

#Copy robots.txt till pre-prod ENVs only. It is not needed in the Prod ENV, so please comment out the line below.
#Copy robots.txt
#Copy robots.txt till pre-prod ENVs only. It is not needed in the Prod ENV, so please comment out the line below.
COPY robots.txt /var/www/aithentic-front-end/

# Copy entrypoint script and set permissions
COPY Build-Script.sh /var/www/aithentic-front-end/
RUN chmod +x /var/www/aithentic-front-end/Build-Script.sh

# Set entrypoint command
ENTRYPOINT ["/var/www/aithentic-front-end/Build-Script.sh"]
