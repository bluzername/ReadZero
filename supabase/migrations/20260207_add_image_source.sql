-- Track the source of article images: 'original', 'unsplash', or 'none'
ALTER TABLE articles ADD COLUMN IF NOT EXISTS image_source text DEFAULT 'original';

-- Store photographer attribution for Unsplash images
-- Example: { "name": "Annie Spratt", "username": "anniespratt", "profile_url": "https://unsplash.com/@anniespratt", "photo_url": "https://unsplash.com/photos/abc123" }
ALTER TABLE articles ADD COLUMN IF NOT EXISTS image_credit jsonb;
