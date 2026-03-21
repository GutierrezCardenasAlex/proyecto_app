DELETE FROM trip_tracking
WHERE driver_id IN (
  'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  'aaaaaaa2-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
  'aaaaaaa3-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
  'aaaaaaa4-aaaa-aaaa-aaaa-aaaaaaaaaaa4',
  'aaaaaaa5-aaaa-aaaa-aaaa-aaaaaaaaaaa5',
  '7b8f6c11-1f39-4d40-8a11-111111111111',
  '7b8f6c22-1f39-4d40-8a22-222222222222',
  '7b8f6c33-1f39-4d40-8a33-333333333333',
  '7b8f6c44-1f39-4d40-8a44-444444444444',
  '7b8f6c55-1f39-4d40-8a55-555555555555'
);

DELETE FROM driver_locations
WHERE driver_id IN (
  'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  'aaaaaaa2-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
  'aaaaaaa3-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
  'aaaaaaa4-aaaa-aaaa-aaaa-aaaaaaaaaaa4',
  'aaaaaaa5-aaaa-aaaa-aaaa-aaaaaaaaaaa5',
  '7b8f6c11-1f39-4d40-8a11-111111111111',
  '7b8f6c22-1f39-4d40-8a22-222222222222',
  '7b8f6c33-1f39-4d40-8a33-333333333333',
  '7b8f6c44-1f39-4d40-8a44-444444444444',
  '7b8f6c55-1f39-4d40-8a55-555555555555'
);

DELETE FROM vehicles
WHERE driver_id IN (
  'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  'aaaaaaa2-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
  'aaaaaaa3-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
  'aaaaaaa4-aaaa-aaaa-aaaa-aaaaaaaaaaa4',
  'aaaaaaa5-aaaa-aaaa-aaaa-aaaaaaaaaaa5',
  '7b8f6c11-1f39-4d40-8a11-111111111111',
  '7b8f6c22-1f39-4d40-8a22-222222222222',
  '7b8f6c33-1f39-4d40-8a33-333333333333',
  '7b8f6c44-1f39-4d40-8a44-444444444444',
  '7b8f6c55-1f39-4d40-8a55-555555555555'
);

DELETE FROM drivers
WHERE user_id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
);

INSERT INTO users (id, phone, full_name, role, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', '+59171100001', 'Juan Quispe', 'driver', NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', '+59171100002', 'Maria Flores', 'driver', NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', '+59171100003', 'Luis Copa', 'driver', NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444444', '+59171100004', 'Rosa Mamani', 'driver', NOW(), NOW()),
  ('55555555-5555-5555-5555-555555555555', '+59171100005', 'Carlos Choque', 'driver', NOW(), NOW())
ON CONFLICT (phone) DO UPDATE
SET full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    updated_at = NOW();

INSERT INTO drivers (id, user_id, license_number, status, is_available, rating, created_at, updated_at)
VALUES
  ('7b8f6c11-1f39-4d40-8a11-111111111111', '11111111-1111-1111-1111-111111111111', 'LIC-POT-001', 'available', TRUE, 4.8, NOW(), NOW()),
  ('7b8f6c22-1f39-4d40-8a22-222222222222', '22222222-2222-2222-2222-222222222222', 'LIC-POT-002', 'available', TRUE, 4.9, NOW(), NOW()),
  ('7b8f6c33-1f39-4d40-8a33-333333333333', '33333333-3333-3333-3333-333333333333', 'LIC-POT-003', 'available', TRUE, 4.7, NOW(), NOW()),
  ('7b8f6c44-1f39-4d40-8a44-444444444444', '44444444-4444-4444-4444-444444444444', 'LIC-POT-004', 'available', TRUE, 4.6, NOW(), NOW()),
  ('7b8f6c55-1f39-4d40-8a55-555555555555', '55555555-5555-5555-5555-555555555555', 'LIC-POT-005', 'available', TRUE, 5.0, NOW(), NOW())
ON CONFLICT (user_id) DO UPDATE
SET license_number = EXCLUDED.license_number,
    status = EXCLUDED.status,
    is_available = EXCLUDED.is_available,
    rating = EXCLUDED.rating,
    updated_at = NOW();

INSERT INTO vehicles (id, driver_id, plate, brand, model, color, year, created_at, updated_at)
VALUES
  ('9c7f6c11-2f39-4d40-8b11-111111111111', '7b8f6c11-1f39-4d40-8a11-111111111111', '1234-ABC', 'Toyota', 'Vitz', 'Blanco', 2020, NOW(), NOW()),
  ('9c7f6c22-2f39-4d40-8b22-222222222222', '7b8f6c22-1f39-4d40-8a22-222222222222', '2345-BCD', 'Suzuki', 'Dzire', 'Plata', 2021, NOW(), NOW()),
  ('9c7f6c33-2f39-4d40-8b33-333333333333', '7b8f6c33-1f39-4d40-8a33-333333333333', '3456-CDE', 'Nissan', 'Versa', 'Azul', 2019, NOW(), NOW()),
  ('9c7f6c44-2f39-4d40-8b44-444444444444', '7b8f6c44-1f39-4d40-8a44-444444444444', '4567-DEF', 'Kia', 'Soluto', 'Rojo', 2022, NOW(), NOW()),
  ('9c7f6c55-2f39-4d40-8b55-555555555555', '7b8f6c55-1f39-4d40-8a55-555555555555', '5678-EFG', 'Hyundai', 'Grand i10', 'Negro', 2023, NOW(), NOW())
ON CONFLICT (driver_id) DO UPDATE
SET plate = EXCLUDED.plate,
    brand = EXCLUDED.brand,
    model = EXCLUDED.model,
    color = EXCLUDED.color,
    year = EXCLUDED.year,
    updated_at = NOW();
