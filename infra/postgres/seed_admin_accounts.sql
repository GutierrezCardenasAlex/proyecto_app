INSERT INTO admin_accounts (phone, username, password_hash, full_name)
VALUES (
  '+59170000001',
  'centralrapigo',
  '$2b$10$c17Q4cIl8rCYLsBdgwrNP.u.w7RFGViG6Zcmgvfy/dRsYu3fVMDna',
  'Central RAPIGO'
)
ON CONFLICT (phone) DO UPDATE
SET username = EXCLUDED.username,
    password_hash = EXCLUDED.password_hash,
    full_name = EXCLUDED.full_name,
    updated_at = NOW();
