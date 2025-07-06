[![Flowzone](https://github.com/balena-io/open-balena/actions/workflows/flowzone.yml/badge.svg)](https://github.com/balena-io/open-balena/actions/workflows/flowzone.yml)

![](./docs/images/openbalena-logo.svg)

[![deploy button](https://balena.io/deploy.svg)](https://dashboard.balena-cloud.com/deploy?repoUrl=https://github.com/balena-io/open-balena)

OpenBalena is a platform to deploy and manage connected devices. Devices run
[balenaOS][balena-os-website], a host operating system designed for running
containers on IoT devices, and are managed via the [balena CLI][balena-cli],
which you can use to configure your application containers, push updates, check
status, view logs, and so forth. OpenBalena’s backend services, composed of
battle-tested components that we’ve run in production on [balenaCloud][balena-cloud-website]
for years, can store device information securely and reliably, allow remote
management via a built-in VPN service, and efficiently distribute container
images to your devices.

To learn more about openBalena, visit [balena.io/open][open-balena-website].

- [Features](#features)
- [Enhanced Services](#enhanced-services)
- [Getting Started](#getting-started)
- [Using the Orchestration Script](#using-the-orchestration-script)
- [Compatibility](#compatibility)
- [Documentation](#documentation)
- [Getting Help](#getting-help)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [Differences between openBalena and balenaCloud](#differences-between-openbalena-and-balenacloud)
- [License](#license)
- [FAQ](#faq)
  - [How do you ensure continuity of openBalena? Are there security patches on openBalena?](#how-do-you-ensure-continuity-of-openbalena-are-there-security-patches-on-openbalena)
  - [How do you ensure the "Join" command actually works between openBalena and](#how-do-you-ensure-the-join-command-actually-works-between-openbalena-and)
  - [Is it "production ready"?](#is-it-production-ready)
  - [Can a new device type be added to openBalena?](#can-a-new-device-type-be-added-to-openbalena)
  - [Are there open-source UI dashboards from the community for openBalena?](#are-there-open-source-ui-dashboards-from-the-community-for-openbalena)



## Features

- **Simple provisioning**: Adding devices to your fleet is a breeze
- **Easy updates**: Remotely update the software on your devices with a single command
- **Container-based**: Benefit from the power of virtualization, optimized for the edge
- **Scalable**: Deploy and manage one device, or one million
- **Powerful API & SDK**: Extend openBalena to fit your needs
- **Built-in VPN**: Access your devices regardless of their network environment

## Enhanced Services

OpenBalena includes additional services that provide enhanced functionality:

### Core Services
- **API**: REST API for device and application management
- **Registry**: Container image registry with delta sync
- **VPN**: Secure device connectivity through NAT/firewalls
- **Database**: PostgreSQL for application and device data
- **S3**: Object storage for images and artifacts
- **Redis**: In-memory cache for improved performance

### Additional Services
- **UI/Admin Dashboard**: Web-based management interface at `https://admin.{DNS_TLD}`
  - Device fleet management
  - Application monitoring
  - User-friendly interface for OpenBalena operations
  
- **Builder**: Container build service at `https://builder.{DNS_TLD}`
  - Multi-architecture container builds
  - Integration with device deployment pipeline
  
- **Delta**: Delta update processing at `https://delta.{DNS_TLD}`
  - Efficient incremental updates
  - Reduced bandwidth usage for device updates
  
- **Helper**: Utility service for downloads and supervisor releases
  - Handles `/download` and `/v6/supervisor_release` endpoints
  - Integrated with API service routing
  
- **PostgREST**: RESTful API for PostgreSQL at `https://postgrest.{DNS_TLD}`
  - Direct database access via REST
  - Automatic API generation from database schema
  
- **Remote**: Device remote access at `https://remote.{DNS_TLD}`
  - SSH and remote terminal access to devices
  - Secure tunneling through OpenBalena infrastructure

### Reverse Proxy & Tunneling
- **Traefik**: Modern reverse proxy with automatic service discovery
- **Cloudflared**: Secure tunnel access without port forwarding
- **Certificate Management**: Automatic SSL/TLS certificate handling

All services are accessible via subdomains of your configured `DNS_TLD` and are automatically routed through Traefik for secure HTTPS access.


## Getting Started

Our [Getting Started guide][getting-started] is the most direct path to getting
an openBalena installation up and running and successfully deploying your
application to your device(s).

## Using the Orchestration Script

OpenBalena includes an orchestration script (`open-balena.sh`) that simplifies common tasks for local development and testing. This script replaces the previous Makefile-based approach.

### Basic Usage

```bash
# Generate environment configuration
./open-balena.sh config

# Configure NFS volumes (optional)
./open-balena.sh nfs-setup

# Start all services
./open-balena.sh up

# Start with automatic LetsEncrypt certificates
./open-balena.sh auto-pki

# Start with custom certificates
./open-balena.sh custom-pki

# Stop all services
./open-balena.sh down

# Show service status
./open-balena.sh status

# View logs for a specific service
./open-balena.sh logs api

# Verify API endpoint and certificates
./open-balena.sh verify

# Lint shell scripts
./open-balena.sh lint
```

### Available Commands

- `help` - Show usage information
- `config` - Generate .env configuration file interactively
- `up` - Start all services with Docker Compose
- `down` - Stop all services
- `restart` - Restart all services
- `destroy` - Stop and remove all containers and volumes
- `auto-pki` - Start all services with automatic PKI (LetsEncrypt/ACME)
- `custom-pki` - Start all services with custom PKI certificates
- `nfs-setup` - Configure NFS volumes for persistent storage
- `status` - Show status of all services
- `logs SERVICE` - Show logs for a specific service
- `verify` - Ping the public API endpoint and verify certificates
- `lint` - Lint shell scripts using shellcheck
- `showenv` - Display current .env configuration
- `showpass` - Show superuser password

The script automatically handles service profiles based on your configuration:
- Uses internal PostgreSQL unless `EXTERNAL_POSTGRES=true`
- Uses internal S3 unless `EXTERNAL_S3=true`
- Waits for services to become healthy before completing startup

### Environment Variables

The script respects the following environment variables:

- `DNS_TLD` - Your domain (required)
- `BALENA_DEVICE_UUID` - Device UUID for Traefik configuration (required)
- `EXTERNAL_POSTGRES` - Use external PostgreSQL (default: false)
- `EXTERNAL_S3` - Use external S3 (default: false)  
- `SUPERUSER_EMAIL` - Admin email (default: admin@$DNS_TLD)
- `VERBOSE` - Enable verbose output (default: false)
- `USE_NFS` - Use NFS volumes for persistent storage (default: false)
- `NFS_HOST` - NFS server hostname or IP (required when USE_NFS=true)
- `NFS_PORT` - NFS server port (default: 2049)
- `NFS_PATH` - NFS mount path (default: /openbalena)

For a complete list of supported environment variables, see the configuration generated by `./open-balena.sh config`.

### NFS Volume Configuration

OpenBalena supports NFS volumes for persistent storage, allowing you to store data on a remote NFS server instead of local Docker volumes. This is useful for:

- Shared storage across multiple OpenBalena instances
- Centralized backup and disaster recovery
- Network-attached storage solutions
- High-availability deployments

#### Setting up NFS Volumes

```bash
# Interactive setup - prompts for NFS server details
./open-balena.sh nfs-setup

# Or set environment variables before setup
export NFS_HOST="192.168.1.100"
export NFS_PORT="2049"
export NFS_PATH="/openbalena"
./open-balena.sh nfs-setup
```

This will:
- Create a `docker-compose.nfs.yml` file with NFS volume definitions
- Update your `.env` file with NFS configuration
- Configure all OpenBalena volumes to use NFS

#### NFS Volume Structure

The NFS setup creates the following directory structure on your NFS server:
```
/openbalena/
├── cert-manager-data/
├── certs-data/
├── db-data/
├── pki-data/
├── redis-data/
├── resin-data/
├── s3-data/
├── builder-storage/
├── delta-storage/
└── helper-storage/
```

#### Using NFS Volumes

Once configured, all orchestration commands automatically use NFS volumes:

```bash
# Start services with NFS volumes
./open-balena.sh up

# Check status (displays NFS configuration)
./open-balena.sh status

# All other commands work normally
./open-balena.sh logs api
./open-balena.sh restart
```

#### NFS Requirements

- NFS server must be accessible from Docker host
- NFS export must allow read/write access
- Recommended NFS version: v4 (automatically used)
- Default port: 2049 (configurable)

Example NFS server configuration (`/etc/exports`):
```
/openbalena *(rw,sync,no_subtree_check,no_root_squash)
```

### PKI Certificate Management

OpenBalena supports multiple PKI certificate management approaches:

#### Automatic PKI (LetsEncrypt/ACME)
For production deployments with automatic certificate management:

```bash
# Configure ACME settings during environment setup
./open-balena.sh config  # Enable ACME and provide email/DNS tokens

# Start with automatic certificate generation
./open-balena.sh auto-pki
```

This will:
- Start all services including cert-manager
- Automatically generate LetsEncrypt certificates
- Wait for certificate validation
- Configure services to use the generated certificates

#### Custom PKI Certificates
For deployments using custom or self-signed certificates:

```bash
# Set custom certificate paths (before starting services)
export HAPROXY_CRT="/path/to/your/certificate.pem"
export TRAEFIK_CRT="/path/to/your/certificate.pem"

# Start with custom certificates
./open-balena.sh custom-pki
```

Custom certificates should be:
- Combined certificate + private key in PEM format
- Accessible to the Docker containers via volume mounts
- Valid for your DNS_TLD domain

#### Verifying Certificates
To verify that certificates are working correctly:

```bash
./open-balena.sh verify
```

This command will:
- Test the API endpoint connectivity
- Verify SSL certificate validity
- Check cert-manager status if running
- Report any certificate-related issues

### Startup Validation

OpenBalena includes automatic validation that runs before starting services to ensure proper configuration:

#### Pre-startup Validation Flow

When running `./open-balena.sh up`, `auto-pki`, or `custom-pki`, the system performs these validations:

1. **DNS_TLD Check** - Ensures your domain is configured
2. **BALENA_DEVICE_UUID Check** - Validates device UUID is set for Traefik configuration
3. **Traefik Migration Validation** - Runs comprehensive validation of Traefik configuration

If any validation fails, the startup process is halted with clear error messages.

#### BALENA_DEVICE_UUID Requirement

The `BALENA_DEVICE_UUID` environment variable is required for Traefik configuration. This unique identifier is used for device-specific routing and configuration.

**Automatic Generation**: When running `./open-balena.sh config`, a UUID is automatically generated if not provided.

**Manual Generation**: You can generate a UUID manually:
```bash
export BALENA_DEVICE_UUID=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
```

#### Traefik Migration Validation

The validation script checks:
- Docker Compose configuration validity
- Traefik configuration file syntax
- Required configuration templates
- Error page availability
- Container build compatibility
- Documentation completeness

**Validation Location**: The validation script is located at `scripts/validate-traefik-migration.sh` and is automatically executed during startup.

#### Error Handling

Clear error messages are provided when validation fails:

```bash
$ ./open-balena.sh up
Error: BALENA_DEVICE_UUID is not set.
Please run 'config' command first or set BALENA_DEVICE_UUID environment variable.
You can generate one with: head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'
```

#### Bypassing Validation

Validation cannot be bypassed as it ensures system integrity. If you encounter validation errors:

1. Run `./open-balena.sh config` to properly configure environment variables
2. Fix any configuration issues reported by the validation script
3. Ensure all required files and templates are present


## Compatibility

The current release of openBalena has the following minimum version requirements:

- balenaOS v5.2.8
- balena CLI v18.2.2

If you are updating from previous openBalena versions, ensure you update the balena
CLI and re-provision any devices to at least the minimum required versions in order
for them to be fully compatible with this release, as some features may not work.

While in-place openBalena upgrades may succeed, when performing major updates, it is
recommended for a new instance to be deployed in parallel with the existing one, followed
by copying state across and pointing a test device to the new instance.


## Documentation

While we're still working on the project documentation, please refer to the
[balenaCloud documentation][documentation]. BalenaCloud is built on top of
openBalena, so the core concepts and functionality is identical. The following
sections are of particular interest:

- [Overview / A balena primer](https://balena.io/docs/learn/welcome/primer)
- [Overview / Core Concepts](https://balena.io/docs/learn/welcome/concepts)
- [Overview / Going to production](https://balena.io/docs/learn/welcome/production-plan)
- [Develop / Define a container](https://balena.io/docs/learn/develop/dockerfile)
- [Develop / Multiple containers](https://balena.io/docs/learn/develop/multicontainer)
- [Develop / Runtime](https://balena.io/docs/learn/develop/runtime)
- [Develop / Interact with hardware](https://balena.io/docs/learn/develop/hardware)
- [Deploy / Optimize your builds](https://balena.io/docs/learn/deploy/build-optimization)
- [Reference](https://balena.io/docs/reference)
- [FAQ](https://balena.io/docs/faq/troubleshooting/faq)


## Getting Help

You are welcome to submit any questions, participate in discussions and request
help with any issue in [openBalena forums][forums]. The balena team frequents
these forums and will be happy to help. You can also ask other community members
for help, or contribute by answering questions posted by fellow openBalena users.
Please do not use the issue tracker for support-related questions.


## Contributing

Everyone is welcome to contribute to openBalena. There are many different ways
to get involved apart from submitting pull requests, including helping other
users on the [forums][forums], reporting or triaging [issues][issue-tracker],
reviewing and discussing [pull requests][pulls], or just spreading the word.

All of openBalena is hosted on GitHub. Apart from its constituent components,
which are the [API][open-balena-api], [VPN][open-balena-vpn], [Registry][open-balena-registry],
[S3 storage service][open-balena-s3], and [Database][open-balena-db], contributions
are also welcome to its client-side software such as the [balena CLI][balena-cli],
the [balena SDK][balena-sdk], [balenaOS][balena-os] and [balenaEngine][balena-engine].


## Roadmap

OpenBalena is currently in beta. While fully functional, it lacks features we
consider important before we can comfortably call it production-ready. During
this phase, don’t be alarmed if things don’t work as expected just yet (and
please let us know about any bugs or errors you encounter!). The following
improvements and new functionality is planned:

- Full documentation
- Full test suite
- Simplified deployment
- Remote host OS updates
- Support for custom device types


## Differences between openBalena and balenaCloud

Whilst openBalena and balenaCloud share the same core technology, there are some key
differences. First, openBalena is self-hosted, whereas balenaCloud is hosted by balena and
therefore handles security, maintenance, scaling, and reliability of all the backend
services. OpenBalena is also single user, whereas balenaCloud supports multiple users and
organizations. OpenBalena also lacks some of the commercial features that define
balenaCloud, such as the web-based dashboard and updates with binary container deltas.

The following table contains the main differences between both:

| openBalena                                                                                 | balenaCloud                                                                                                                                                                                               |
| ------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Device updates using full Docker images                                                    | Device updates using [delta images](https://www.balena.io/docs/learn/deploy/delta/)                                                                                                                       |
| Support for a single user                                                                  | Support for [multiple users](https://www.balena.io/docs/learn/manage/account/#application-members)                                                                                                        |
| Self-hosted deployment and scaling                                                         | balena-managed scaling and deployment                                                                                                                                                                     |
| Community support via [forums][forums]                                                     | Private support on [paid plans](https://www.balena.io/pricing/)                                                                                                                                           |
| Build locally and deploy via `balena-cli`                                                  | Build remotely with native builders using [`balena push`](https://www.balena.io/docs/learn/deploy/deployment/#balena-push) or  [`git push`](https://www.balena.io/docs/learn/deploy/deployment/#git-push) |
| No public device URL support                                                               | Serve websites directly from device with [public device URLs](https://www.balena.io/docs/learn/manage/actions/#enable-public-device-url)                                                                  |
| Management via `balena-cli` only                                                           | Cloud-based device management dashboard                                                                                                                                                                   |
| Download images from [balena.io][balena-os-website] and configure locally via `balena-cli` | Download configured images directly from the dashboard                                                                                                                                                    |
| No remote device diagnostics                                                               | Remote device diagnostics                                                                                                                                                                                 |

Additionally, refer back to the [roadmap](#roadmap) above for planned but not yet
implemented features.


## License

OpenBalena is licensed under the terms of AGPL v3. See [LICENSE] for details.


## FAQ

### How do you ensure continuity of openBalena? Are there security patches on openBalena?
openBalena is an open source initiative which is mostly driven by us, but it also gets
contributions from the community. We work to keep openBalena as up to date as our
bandwidth allows, especially with security patches. That said, we do not have a policy or
guarantee of a software release schedule. However, it is in our best interest to keep
openBalena updated and patched since we also use it for balenaCloud.

### How do you ensure the "Join" command actually works between openBalena and
balenaCloud?
The `balena join ..` command is frequently used for moving devices between openBalena,
and balenaCloud environments. This command extends `balena os configure ..`, which is the
basic tool balena uses for configuring devices.

### Is it "production ready"?
While we actually have some rather large fleets using openBalena, we consider it to be
perpetually in "beta". This means potentially introducing breaking changes between
releases.

### Can a new device type be added to openBalena?
openBalena imports the following public [device-types] "out of the box". You can specify
your own contracts repository by overriding `CONTRACTS_PUBLIC_REPO_NAME`,
`CONTRACTS_PUBLIC_REPO_OWNER` and `IMAGE_STORAGE_BUCKET` environment variables on the API
service/container.

### Are there open-source UI dashboards from the community for openBalena?
Yes! Here are a few:
- [open-balena-admin / open-balena-ui](https://github.com/dcaputo-harmoni/open-balena-admin) by [dcaputo-harmoni](https://github.com/dcaputo-harmoni) who first posted about [here](https://forums.balena.io/t/open-balena-admin-an-admin-interface-for-openbalena/355324) in our Forums :)
- [open-balena-dashboard](https://github.com/Razikus/open-balena-dashboard) by [Razikus](https://github.com/Razikus)


[balena-cli]: https://github.com/balena-io/balena-cli
[balena-cloud-website]: https://balena.io/cloud
[balena-engine]: https://github.com/balena-os/balena-engine
[balena-os-website]: https://balena.io/os
[balena-os]: https://github.com/balena-os/meta-balena
[balena-sdk]: https://github.com/balena-io/balena-sdk
[documentation]: https://balena.io/docs/learn/welcome/introduction/
[forums]: https://forums.balena.io/c/open-balena
[getting-started]: https://balena.io/open/docs/getting-started
[issue-tracker]: https://github.com/balena-io/open-balena/issues
[LICENSE]: https://github.com/balena-io/open-balena/blob/master/LICENSE
[open-balena-admin / open-balena-ui]: https://github.com/dcaputo-harmoni/open-balena-admin
[open-balena-api]: https://github.com/balena-io/open-balena-api
[open-balena-dashboard]: https://github.com/Razikus/open-balena-dashboard
[open-balena-db]: https://github.com/balena-io/open-balena-db
[open-balena-registry]: https://github.com/balena-io/open-balena-registry
[open-balena-s3]: https://github.com/balena-io/open-balena-s3
[open-balena-vpn]: https://github.com/balena-io/open-balena-vpn
[open-balena-website]: https://balena.io/open
[pulls]: https://github.com/balena-io/open-balena/pulls
[device-types]: https://github.com/balena-io/contracts/blob/master/contracts/hw.device-type
