-- Landmarks: seed data
-- Well-known landmarks and the starter badge set, so the app has something to
-- render before any user submits content. Safe to re-run.

insert into public.landmarks (slug, name, description, category, location, city, country_code, is_verified)
values
  ('eiffel-tower', 'Eiffel Tower', 'Wrought-iron lattice tower on the Champ de Mars.', 'monument',
   extensions.st_makepoint(2.2945, 48.8584)::extensions.geography, 'Paris', 'FR', true),
  ('louvre-museum', 'Louvre Museum', 'The world''s most-visited museum, in a former royal palace.', 'museum',
   extensions.st_makepoint(2.3376, 48.8606)::extensions.geography, 'Paris', 'FR', true),
  ('sagrada-familia', 'Sagrada Familia', 'Gaudi''s unfinished basilica.', 'building',
   extensions.st_makepoint(2.1744, 41.4036)::extensions.geography, 'Barcelona', 'ES', true),
  ('park-guell', 'Park Guell', 'Mosaic-covered public park on Carmel Hill.', 'park',
   extensions.st_makepoint(2.1527, 41.4145)::extensions.geography, 'Barcelona', 'ES', true),
  ('colosseum', 'Colosseum', 'Roman amphitheatre in the centre of the city.', 'monument',
   extensions.st_makepoint(12.4922, 41.8902)::extensions.geography, 'Rome', 'IT', true),
  ('belem-tower', 'Belem Tower', 'Sixteenth-century fortified tower on the Tagus.', 'monument',
   extensions.st_makepoint(-9.2160, 38.6916)::extensions.geography, 'Lisbon', 'PT', true),
  ('miradouro-da-senhora-do-monte', 'Miradouro da Senhora do Monte', 'The highest viewpoint over the city.', 'viewpoint',
   extensions.st_makepoint(-9.1330, 38.7189)::extensions.geography, 'Lisbon', 'PT', true),
  ('jeronimos-monastery', 'Jeronimos Monastery', 'Manueline monastery in Belem.', 'building',
   extensions.st_makepoint(-9.2067, 38.6979)::extensions.geography, 'Lisbon', 'PT', true),
  ('statue-of-liberty', 'Statue of Liberty', 'Neoclassical colossus on Liberty Island.', 'monument',
   extensions.st_makepoint(-74.0445, 40.6892)::extensions.geography, 'New York', 'US', true),
  ('central-park', 'Central Park', 'Urban park spanning the middle of Manhattan.', 'park',
   extensions.st_makepoint(-73.9654, 40.7829)::extensions.geography, 'New York', 'US', true),
  ('the-met', 'The Metropolitan Museum of Art', 'Encyclopedic art museum on Museum Mile.', 'museum',
   extensions.st_makepoint(-73.9632, 40.7794)::extensions.geography, 'New York', 'US', true),
  ('golden-gate-bridge', 'Golden Gate Bridge', 'Suspension bridge across the Golden Gate strait.', 'building',
   extensions.st_makepoint(-122.4783, 37.8199)::extensions.geography, 'San Francisco', 'US', true),
  ('twin-peaks', 'Twin Peaks', 'Two hills with a panoramic view of the bay.', 'viewpoint',
   extensions.st_makepoint(-122.4477, 37.7544)::extensions.geography, 'San Francisco', 'US', true),
  ('tokyo-tower', 'Tokyo Tower', 'Communications and observation tower in Minato.', 'monument',
   extensions.st_makepoint(139.7454, 35.6586)::extensions.geography, 'Tokyo', 'JP', true),
  ('mount-fuji', 'Mount Fuji', 'Japan''s highest peak and an active stratovolcano.', 'natural',
   extensions.st_makepoint(138.7274, 35.3606)::extensions.geography, 'Fujinomiya', 'JP', true),
  ('christ-the-redeemer', 'Christ the Redeemer', 'Art deco statue atop Corcovado mountain.', 'monument',
   extensions.st_makepoint(-43.2105, -22.9519)::extensions.geography, 'Rio de Janeiro', 'BR', true)
on conflict (slug) do nothing;

insert into public.badges (slug, name, description, icon, criteria)
values
  ('first-steps', 'First Steps', 'Logged your first check-in.', 'figure.walk',
   '{"type": "visit_count", "count": 1}'::jsonb),
  ('getting-around', 'Getting Around', 'Logged 10 check-ins.', 'map',
   '{"type": "visit_count", "count": 10}'::jsonb),
  ('seasoned-traveler', 'Seasoned Traveler', 'Logged 50 check-ins.', 'airplane',
   '{"type": "visit_count", "count": 50}'::jsonb),
  ('museum-goer', 'Museum Goer', 'Visited 5 different museums.', 'building.columns',
   '{"type": "category_count", "category": "museum", "count": 5}'::jsonb),
  ('park-life', 'Park Life', 'Visited 5 different parks.', 'tree',
   '{"type": "category_count", "category": "park", "count": 5}'::jsonb),
  ('room-with-a-view', 'Room With a View', 'Visited 3 different viewpoints.', 'binoculars',
   '{"type": "category_count", "category": "viewpoint", "count": 3}'::jsonb),
  ('lisbon-local', 'Lisbon Local', 'Visited 3 landmarks in Lisbon.', 'tram',
   '{"type": "city_count", "city": "Lisbon", "count": 3}'::jsonb),
  ('paris-in-a-day', 'Paris in a Day', 'Visited 2 landmarks in Paris.', 'fork.knife',
   '{"type": "city_count", "city": "Paris", "count": 2}'::jsonb),
  ('top-of-the-tower', 'Top of the Tower', 'Checked in at the Eiffel Tower.', 'sparkles',
   '{"type": "landmark", "slug": "eiffel-tower"}'::jsonb)
on conflict (slug) do nothing;
