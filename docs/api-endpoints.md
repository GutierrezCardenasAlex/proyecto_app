# Taxi Ya API Endpoints

## Gateway

Base URL: `http://localhost:3000/api`

## Auth

- `POST /auth/otp/request`
- `POST /auth/otp/verify`

## Drivers

- `POST /drivers/profile`
- `PATCH /drivers/availability`
- `GET /drivers/:driverId`

## Trips

- `POST /trips`
- `GET /trips/:tripId`
- `GET /trips/history/:passengerId`
- `PATCH /trips/:tripId/status`

## Dispatch

- `POST /dispatch/search`
- `POST /dispatch/accept`

## Locations

- `POST /locations/drivers`
- `GET /locations/drivers/:driverId`

## Notifications

- `POST /notifications/push`

## Admin

- `GET /admin/dashboard`
- `GET /admin/active-trips`
- `GET /admin/drivers/live`

## WebSocket events

Socket URL: `http://localhost:3008`

Client events:

- `join:trip`
- `join:driver`
- `join:admin`

Server events:

- `driver:location`
- `trip:tracking`
