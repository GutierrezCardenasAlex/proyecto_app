# Taxi Ya

Taxi Ya is a production-oriented ride-hailing platform for Potosi, Bolivia. This repository contains a Dockerized microservices backend, a React admin panel, and Flutter passenger/driver apps.

## Architecture

- `services/`: Fastify-based microservices
- `admin/`: React + Vite admin dashboard
- `mobile/passenger_app/`: Flutter passenger app
- `mobile/driver_app/`: Flutter driver app
- `infra/postgres/schema.sql`: PostgreSQL + PostGIS schema
- `docker-compose.yml`: local orchestration for all components

## Core constraints

- City center fixed at `(-19.5836, -65.7531)`
- Maximum service radius is `15 km`
- Dispatch search radius is `3 km`
- Driver GPS updates expected every `5 seconds`

## Services

- `gateway-api`: single entrypoint, auth middleware, route proxy
- `auth-service`: OTP login and JWT issuance
- `driver-service`: driver profiles, vehicles, availability
- `trip-service`: trip creation and lifecycle
- `dispatch-service`: PostGIS nearest driver search and assignment lock
- `location-service`: Redis + PostgreSQL location storage and fan-out
- `notification-service`: FCM integration point
- `admin-service`: dashboard and analytics APIs
- `websocket-service`: Socket.IO real-time server

## Run locally

1. Copy the root environment:

```powershell
Copy-Item .env.example .env
```

2. Start infrastructure and services:

```powershell
docker compose up --build
```

3. Start the admin panel locally for development:

```powershell
cd admin
Copy-Item .env.example .env
npm install
npm run dev
```

4. Start Flutter apps:

```powershell
cd mobile/passenger_app
flutter pub get
flutter run
```

```powershell
cd mobile/driver_app
flutter pub get
flutter run
```

## Verify the stack

After `docker compose up --build`, run:

```powershell
.\scripts\verify-stack.ps1
```

On Ubuntu/Linux:

```bash
chmod +x ./scripts/verify-stack.sh ./scripts/smoke-auth.sh
./scripts/verify-stack.sh
```

This checks:

- all required containers are running
- internal `/health` endpoints for every microservice
- gateway availability on `http://localhost:3000/health`
- RabbitMQ management UI on `http://localhost:15672`

To run a simple auth smoke test through the gateway:

```powershell
.\scripts\smoke-auth.ps1
```

On Ubuntu/Linux:

```bash
./scripts/smoke-auth.sh
```

## Production notes

- All backend services are stateless and horizontally scalable.
- Redis is used for hot location data and short-lived dispatch locks.
- RabbitMQ is used for asynchronous event propagation.
- PostgreSQL + PostGIS remains the source of truth for trips and historical locations.
- Put the gateway and websocket services behind a load balancer with sticky sessions only if your Socket.IO adapter requires it.
