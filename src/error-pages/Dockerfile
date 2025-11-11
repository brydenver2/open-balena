# Error Pages Server for OpenBalena Traefik
# Provides custom error pages for HTTP error responses (404, 500, etc.)
# Used by Traefik reverse proxy to display user-friendly error messages
# 
# This lightweight nginx server serves static HTML error pages
# that are displayed when services are unavailable or return errors

FROM nginx:alpine

# Copy custom error pages
COPY html/ /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]