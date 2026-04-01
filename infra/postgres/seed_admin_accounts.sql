INSERT INTO admin_accounts (phone, full_name)
VALUES ('+59170000001', 'Central Taxi Ya')
ON CONFLICT (phone) DO UPDATE
SET full_name = EXCLUDED.full_name,
    updated_at = NOW();
