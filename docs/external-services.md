# External Service Configuration

OpenBalena supports using external PostgreSQL and S3/MinIO services instead of the built-in containers. This can be useful for production deployments where you want to use managed database and storage services.

## External PostgreSQL Configuration

To use an external PostgreSQL server, you can either:

1. **Use the automated configuration script** (recommended):
   ```bash
   ./open-balena.sh config
   # Answer "y" when prompted for external Postgres
   # Then provide your database connection details
   ./open-balena.sh up
   ```

2. **Set environment variables manually**:
   - `EXTERNAL_POSTGRES=true` - Enable external PostgreSQL mode
   - `EXTERNAL_POSTGRES_HOST` - PostgreSQL server hostname
   - `EXTERNAL_POSTGRES_PORT` - PostgreSQL server port (default: 5432)
   - `EXTERNAL_POSTGRES_USER` - PostgreSQL username
   - `EXTERNAL_POSTGRES_PASSWORD` - PostgreSQL password
   - `EXTERNAL_POSTGRES_DATABASE` - PostgreSQL database name

### Manual Environment Variable Example:

```bash
# Set these in your .env file or environment
EXTERNAL_POSTGRES=true
EXTERNAL_POSTGRES_HOST=10.0.10.99
EXTERNAL_POSTGRES_PORT=5432
EXTERNAL_POSTGRES_USER=balena
EXTERNAL_POSTGRES_PASSWORD=your_secure_password
EXTERNAL_POSTGRES_DATABASE=balena

# Then start the services
./open-balena.sh up
```

When `EXTERNAL_POSTGRES=true` is set, the internal PostgreSQL database container will be automatically disabled, and the API service will connect to your external database using these credentials.



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
# Using the configuration script (recommended)
./open-balena.sh config
# Answer "y" for both external Postgres and S3
# Provide your connection details
./open-balena.sh up

# Or set environment variables manually:
EXTERNAL_POSTGRES=true
EXTERNAL_POSTGRES_HOST=postgres.example.com
EXTERNAL_POSTGRES_USER=balena
EXTERNAL_POSTGRES_PASSWORD=securepassword
EXTERNAL_POSTGRES_DATABASE=balena
EXTERNAL_S3=true
EXTERNAL_S3_ENDPOINT=minio.example.com
EXTERNAL_S3_ACCESS_KEY=minioadmin
EXTERNAL_S3_SECRET_KEY=minioadmin

# Then start the services
./open-balena.sh up
```

## Notes

- When using external services, the corresponding internal containers (db/s3) will not be started automatically
- Ensure your external PostgreSQL database is properly initialized with the required schema before starting OpenBalena
- The PostgreSQL version should be compatible with the version used by the internal container (currently PostgreSQL 13+)
- For S3/MinIO, ensure the required buckets (`registry-data`, `web-resources`) exist
- External services must be accessible from the Docker network where OpenBalena is running
- For PostgreSQL connectivity, ensure your database accepts connections from the OpenBalena host and allows the specified user/password combination
- The open-balena-api container uses the `pg` npm package which supports modern PostgreSQL authentication methods including SCRAM-SHA-256