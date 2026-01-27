# Changelog

All notable changes to the Apish project components will be documented in this file.

---
## 2026-01-27

### apish-converter:3.0.2
- Increase maximum file size limit for document conversion input files

### docker-compose.yml
- Don't expose RabbitMQ management UI by default
- Upgrade RabbitMQ to version 4.2
    - **Note:** Upgrading will result in loss of existing queue data. Suggested upgrade procedure:
        1. Stop Web container
        2. Wait until all running comparisons complete
        3. Stop all APISH services
        4. Replace docker-compose.yml and start all services


---
## 2026-01-08

### apish-web:3.0.5
- Fix security vulnerability CVE-2025-69223
- Compatibility with Podman

### apish-load-balancer:3.0.2, docker-compose.yml
- Compatibility with Podman

### apish-compare:3.0.1
- Improve logging and error handling 

---
## 2025-12-02

### apish-web:3.0.4, docker-compose.yml
- Support for configuring S3 storage

### docker-compose.yml
- Redis improved data persistence options

---
## 2025-11-26

### apish-web:3.0.3, apish-converter:3.0.1, docker-compose.yml
- Added a script and instructions for migrating from V2 APISH container
- Support for installing custom fonts

### docker-compose.yml
- Update Redis to v8.2

---
## 2025-11-13

### apish-web:3.0.2
- Fix error 500 when accessing user account after modification

### apish-load-balancer:3.0.1
- Fix support for large input files

---
## 2025-11-06

### apish-web:3.0.1
- Fix django vulnerability CVE-2025-64459

### docker-compose.yml
- Add support for configuring REDIS_PASSWORD

---
## 2025-09-30

- Initial release of V3 API Self Hosted solution
