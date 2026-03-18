CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('passenger', 'driver', 'admin');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'driver_status') THEN
    CREATE TYPE driver_status AS ENUM ('offline', 'available', 'busy', 'suspended');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trip_status') THEN
    CREATE TYPE trip_status AS ENUM (
      'requested',
      'searching',
      'accepted',
      'arriving',
      'in_progress',
      'completed',
      'cancelled',
      'expired'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone VARCHAR(32) UNIQUE NOT NULL,
  full_name VARCHAR(120),
  role user_role NOT NULL DEFAULT 'passenger',
  otp_code VARCHAR(8),
  otp_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS drivers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  license_number VARCHAR(64) NOT NULL,
  status driver_status NOT NULL DEFAULT 'offline',
  is_available BOOLEAN NOT NULL DEFAULT FALSE,
  rating NUMERIC(3,2) NOT NULL DEFAULT 5.0,
  current_trip_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehicles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id UUID NOT NULL UNIQUE REFERENCES drivers(id) ON DELETE CASCADE,
  plate VARCHAR(32) NOT NULL UNIQUE,
  brand VARCHAR(64) NOT NULL,
  model VARCHAR(64) NOT NULL,
  color VARCHAR(32) NOT NULL,
  year SMALLINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trips (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  passenger_id UUID NOT NULL REFERENCES users(id),
  driver_id UUID REFERENCES drivers(id),
  status trip_status NOT NULL DEFAULT 'requested',
  pickup_address TEXT,
  destination_address TEXT,
  pickup_location GEOGRAPHY(POINT, 4326) NOT NULL,
  destination_location GEOGRAPHY(POINT, 4326) NOT NULL,
  estimated_distance_meters INTEGER,
  estimated_duration_seconds INTEGER,
  fare_amount NUMERIC(10,2),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS driver_locations (
  id BIGSERIAL PRIMARY KEY,
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  heading NUMERIC(6,2),
  speed_kph NUMERIC(6,2),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trip_tracking (
  id BIGSERIAL PRIMARY KEY,
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trip_events (
  id BIGSERIAL PRIMARY KEY,
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  event_type VARCHAR(64) NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_locations_driver_time
  ON driver_locations (driver_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_driver_locations_geo
  ON driver_locations
  USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_trip_tracking_trip_time
  ON trip_tracking (trip_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_trip_tracking_geo
  ON trip_tracking
  USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_trips_status
  ON trips (status, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_trips_pickup_geo
  ON trips
  USING GIST (pickup_location);
