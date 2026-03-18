# Taxi Ya Setup

## Local development

1. Start infrastructure and backend services:

```powershell
Copy-Item .env.example .env
docker compose up --build
```

2. Start the admin panel:

```powershell
cd admin
Copy-Item .env.example .env
npm install
npm run dev
```

3. Start the passenger app:

```bash
cd mobile/passenger_app
flutter pub get
flutter run
```

4. Start the driver app:

```bash
cd mobile/driver_app
flutter pub get
flutter run
```

## Environment variables

Important backend variables are already wired in `docker-compose.yml`.

- `DATABASE_URL`
- `REDIS_URL`
- `RABBITMQ_URL`
- `JWT_SECRET`
- `FCM_PROJECT_ID`
- `FCM_CLIENT_EMAIL`
- `FCM_PRIVATE_KEY`

## Scale strategy

- Keep services stateless and scale them behind a reverse proxy.
- Scale `dispatch-service`, `location-service`, and `websocket-service` first.
- Add a Redis-backed Socket.IO adapter before multi-instance websocket rollout.
- Use PostgreSQL read replicas for analytics-heavy admin workloads.
