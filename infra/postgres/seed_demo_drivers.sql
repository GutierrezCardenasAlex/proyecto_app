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
  ('aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', 'LIC-POT-001', 'available', TRUE, 4.8, NOW(), NOW()),
  ('aaaaaaa2-aaaa-aaaa-aaaa-aaaaaaaaaaa2', '22222222-2222-2222-2222-222222222222', 'LIC-POT-002', 'available', TRUE, 4.9, NOW(), NOW()),
  ('aaaaaaa3-aaaa-aaaa-aaaa-aaaaaaaaaaa3', '33333333-3333-3333-3333-333333333333', 'LIC-POT-003', 'available', TRUE, 4.7, NOW(), NOW()),
  ('aaaaaaa4-aaaa-aaaa-aaaa-aaaaaaaaaaa4', '44444444-4444-4444-4444-444444444444', 'LIC-POT-004', 'available', TRUE, 4.6, NOW(), NOW()),
  ('aaaaaaa5-aaaa-aaaa-aaaa-aaaaaaaaaaa5', '55555555-5555-5555-5555-555555555555', 'LIC-POT-005', 'available', TRUE, 5.0, NOW(), NOW())
ON CONFLICT (user_id) DO UPDATE
SET license_number = EXCLUDED.license_number,
    status = EXCLUDED.status,
    is_available = EXCLUDED.is_available,
    rating = EXCLUDED.rating,
    updated_at = NOW();

INSERT INTO vehicles (id, driver_id, plate, brand, model, color, year, created_at, updated_at)
VALUES
  ('bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '1234-ABC', 'Toyota', 'Vitz', 'Blanco', 2020, NOW(), NOW()),
  ('bbbbbbb2-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'aaaaaaa2-aaaa-aaaa-aaaa-aaaaaaaaaaa2', '2345-BCD', 'Suzuki', 'Dzire', 'Plata', 2021, NOW(), NOW()),
  ('bbbbbbb3-bbbb-bbbb-bbbb-bbbbbbbbbbb3', 'aaaaaaa3-aaaa-aaaa-aaaa-aaaaaaaaaaa3', '3456-CDE', 'Nissan', 'Versa', 'Azul', 2019, NOW(), NOW()),
  ('bbbbbbb4-bbbb-bbbb-bbbb-bbbbbbbbbbb4', 'aaaaaaa4-aaaa-aaaa-aaaa-aaaaaaaaaaa4', '4567-DEF', 'Kia', 'Soluto', 'Rojo', 2022, NOW(), NOW()),
  ('bbbbbbb5-bbbb-bbbb-bbbb-bbbbbbbbbbb5', 'aaaaaaa5-aaaa-aaaa-aaaa-aaaaaaaaaaa5', '5678-EFG', 'Hyundai', 'Grand i10', 'Negro', 2023, NOW(), NOW())
ON CONFLICT (driver_id) DO UPDATE
SET plate = EXCLUDED.plate,
    brand = EXCLUDED.brand,
    model = EXCLUDED.model,
    color = EXCLUDED.color,
    year = EXCLUDED.year,
    updated_at = NOW();
