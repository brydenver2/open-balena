# Error pages server for Traefik
FROM nginx:alpine

# Copy custom error pages
COPY html/ /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]