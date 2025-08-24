# External Service Configuration

OpenBalena supports using external PostgreSQL and S3/MinIO services instead of the built-in containers. This can be useful for production deployments where you want to use managed database and storage services.

## External PostgreSQL Configuration

To use an external PostgreSQL server, set the following environment variables:

- `EXTERNAL_POSTGRES=true` - Enable external PostgreSQL mode
- `EXTERNAL_POSTGRES_HOST` - PostgreSQL server hostname
- `EXTERNAL_POSTGRES_PORT` - PostgreSQL server port (default: 5432)
- `EXTERNAL_POSTGRES_USER` - PostgreSQL username
- `EXTERNAL_POSTGRES_PASSWORD` - PostgreSQL password
- `EXTERNAL_POSTGRES_DATABASE` - PostgreSQL database name

### Example:

```bash
DNS_TLD=mybalena.local \
EXTERNAL_POSTGRES=true \
EXTERNAL_POSTGRES_HOST=postgres.example.com \
EXTERNAL_POSTGRES_USER=balena \
EXTERNAL_POSTGRES_PASSWORD=securepassword \
EXTERNAL_POSTGRES_DATABASE=balena \
make up
```



## External S3/MinIO Configuration

To use an external S3-compatible service (like MinIO), set the following environment variables:

- `EXTERNAL_S3=true` - Enable external S3 mode
- `EXTERNAL_S3_ENDPOINT` - S3/MinIO server endpoint
- `EXTERNAL_S3_ACCESS_KEY` - S3/MinIO access key
- `EXTERNAL_S3_SECRET_KEY` - S3/MinIO secret key
- `EXTERNAL_S3_REGION` - S3/MinIO region (default: us-east-1)

### Example:

```bash
DNS_TLD=mybalena.local \
EXTERNAL_S3=true \
EXTERNAL_S3_ENDPOINT=minio.example.com \
EXTERNAL_S3_ACCESS_KEY=minioadmin \
EXTERNAL_S3_SECRET_KEY=minioadmin \
make up
```

## Using Both External Services

You can combine both external PostgreSQL and S3 services:

```bash
DNS_TLD=mybalena.local \
EXTERNAL_POSTGRES=true \
EXTERNAL_POSTGRES_HOST=postgres.example.com \
EXTERNAL_POSTGRES_USER=balena \
EXTERNAL_POSTGRES_PASSWORD=securepassword \
EXTERNAL_POSTGRES_DATABASE=balena \
EXTERNAL_S3=true \
EXTERNAL_S3_ENDPOINT=minio.example.com \
EXTERNAL_S3_ACCESS_KEY=minioadmin \
EXTERNAL_S3_SECRET_KEY=minioadmin \
make up
```

## Notes

- When using external services, the corresponding internal containers (db/s3) will not be started
- Ensure your external PostgreSQL database is properly initialized with the required schema
- For S3/MinIO, ensure the required buckets (`registry-data`, `web-resources`) exist
- External services must be accessible from the Docker network where OpenBalena is running
- TLS/SSL configuration for external services should be handled at the external service level