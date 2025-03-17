# Apache Nginx WordPress Deployment

## Project Overview

This project provides a set of scripts to automate the deployment of a WordPress instance with Nginx as a reverse proxy, Apache for serving PHP, MariaDB for the database, and Redis for caching. It also includes security features such as ModSecurity and UFW.

## System Architecture

The system architecture consists of the following components:

*   Nginx: Reverse proxy and static content server
*   Apache: Serves PHP files using PHP-FPM
*   MariaDB: Database server
*   Redis: Object caching

## Prerequisites

*   Ubuntu 24.04 LTS
*   Minimum 2GB RAM
*   Root/sudo access
*   Domain name configured

## Installation

1.  Clone this repository.
2.  Run `server-setup.sh` to install and configure the server.
3.  Run `deploy-wordpress.sh` to deploy a new WordPress instance.

## Usage

### server-setup.sh

This script installs and configures the server.

```bash
chmod +x server-setup.sh
sudo ./server-setup.sh
```

### deploy-wordpress.sh

This script deploys a new WordPress instance.

```bash
./deploy-wordpress.sh johndoe blog example.com
```

## Security Features

*   ModSecurity with OWASP CRS
*   UFW firewall rules
*   Database name obfuscation
*   User isolation model

## Directory Structure

```
/srv/
└── {username}/
    └── apps/
        └── {appname}/
            ├── public_html/  # WordPress root
            ├── logs/         # Access/error logs
            ├── ssl/          # TLS certificates
            └── configs/      # Server configs
```

