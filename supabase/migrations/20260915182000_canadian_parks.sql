-- Landmarks: add Canada to the park catalog.
--
-- Provinces and territories use the same two-letter shape as US states, so
-- state_codes carries them unchanged, but the catalog now needs a country to
-- tell MT from MB.

alter table public.parks add column country_code char(2) not null default 'US';

create index parks_country_idx on public.parks (country_code);

-- Return type changes, so the function is replaced rather than altered.
drop function public.parks_nearby(double precision, double precision, double precision, integer);

create or replace function public.parks_nearby(
  lat double precision,
  lng double precision,
  radius_meters double precision default 200000,
  max_results integer default 25
)
returns table (
  id uuid,
  slug text,
  name text,
  state_codes char(2)[],
  country_code char(2),
  cover_photo_url text,
  distance_meters double precision
)
language sql
stable
set search_path = ''
as $$
  select
    p.id,
    p.slug,
    p.name,
    p.state_codes,
    p.country_code,
    p.cover_photo_url,
    extensions.st_distance(p.location, extensions.st_makepoint(lng, lat)::extensions.geography) as distance_meters
  from public.parks p
  where extensions.st_dwithin(p.location, extensions.st_makepoint(lng, lat)::extensions.geography, radius_meters)
  order by distance_meters
  limit max_results;
$$;

-- ---------------------------------------------------------------------------
-- Canada's national parks and national park reserves
-- ---------------------------------------------------------------------------
--
-- Coordinates are approximate centroids, as with the US parks. Reserves are
-- included because visitors do not meaningfully distinguish them. Canada's
-- Glacier takes the slug `glacier-canada` because Montana's Glacier already
-- holds `glacier`.

insert into public.parks (slug, name, description, location, state_codes, country_code, is_verified)
values
  ('akami-uapishku', 'Akami-Uapishku-KakKasuak-Mealy Mountains', 'Boreal wilderness, caribou and the Mealy Mountains above Lake Melville.',
   extensions.st_makepoint(-59.00, 53.30)::extensions.geography, '{NL}', 'CA', true),
  ('aulavik', 'Aulavik', 'Arctic badlands and the Thomsen River on Banks Island.',
   extensions.st_makepoint(-119.50, 73.75)::extensions.geography, '{NT}', 'CA', true),
  ('auyuittuq', 'Auyuittuq', 'Granite towers, fjords and the Penny Ice Cap on Baffin Island.',
   extensions.st_makepoint(-65.00, 67.50)::extensions.geography, '{NU}', 'CA', true),
  ('banff', 'Banff', 'Canada''s first national park, all turquoise lakes and Rockies.',
   extensions.st_makepoint(-115.93, 51.50)::extensions.geography, '{AB}', 'CA', true),
  ('bruce-peninsula', 'Bruce Peninsula', 'Limestone cliffs and clear water along the Niagara Escarpment.',
   extensions.st_makepoint(-81.55, 45.23)::extensions.geography, '{ON}', 'CA', true),
  ('cape-breton-highlands', 'Cape Breton Highlands', 'Ocean, mountains and the Cabot Trail along the Atlantic.',
   extensions.st_makepoint(-60.65, 46.75)::extensions.geography, '{NS}', 'CA', true),
  ('elk-island', 'Elk Island', 'A fenced island of aspen parkland that saved the plains bison.',
   extensions.st_makepoint(-112.85, 53.60)::extensions.geography, '{AB}', 'CA', true),
  ('forillon', 'Forillon', 'Cliffs, seals and the end of the Appalachians meeting the Gulf.',
   extensions.st_makepoint(-64.35, 48.85)::extensions.geography, '{QC}', 'CA', true),
  ('fundy', 'Fundy', 'The highest tides in the world, and forest above the Bay of Fundy.',
   extensions.st_makepoint(-65.00, 45.60)::extensions.geography, '{NB}', 'CA', true),
  ('georgian-bay-islands', 'Georgian Bay Islands', 'Windswept pines on granite islands reachable only by boat.',
   extensions.st_makepoint(-79.87, 44.88)::extensions.geography, '{ON}', 'CA', true),
  ('glacier-canada', 'Glacier', 'Deep snowpack, Rogers Pass and the Columbia Mountains.',
   extensions.st_makepoint(-117.52, 51.30)::extensions.geography, '{BC}', 'CA', true),
  ('grasslands', 'Grasslands', 'Prairie, badlands and some of the darkest skies in Canada.',
   extensions.st_makepoint(-107.50, 49.15)::extensions.geography, '{SK}', 'CA', true),
  ('gros-morne', 'Gros Morne', 'Fjords and exposed mantle rock on Newfoundland''s west coast.',
   extensions.st_makepoint(-57.75, 49.60)::extensions.geography, '{NL}', 'CA', true),
  ('gulf-islands', 'Gulf Islands', 'Arbutus, tidepools and island coastline in the Salish Sea.',
   extensions.st_makepoint(-123.32, 48.79)::extensions.geography, '{BC}', 'CA', true),
  ('gwaii-haanas', 'Gwaii Haanas', 'Haida village sites and rainforest islands off the north coast.',
   extensions.st_makepoint(-131.45, 52.42)::extensions.geography, '{BC}', 'CA', true),
  ('ivvavik', 'Ivvavik', 'The British Mountains and the Porcupine caribou calving grounds.',
   extensions.st_makepoint(-140.00, 69.17)::extensions.geography, '{YT}', 'CA', true),
  ('jasper', 'Jasper', 'The largest park in the Canadian Rockies, and a dark sky preserve.',
   extensions.st_makepoint(-117.95, 52.87)::extensions.geography, '{AB}', 'CA', true),
  ('kejimkujik', 'Kejimkujik', 'Canoe routes, hemlock forest and Mi''kmaq petroglyphs.',
   extensions.st_makepoint(-65.22, 44.40)::extensions.geography, '{NS}', 'CA', true),
  ('kluane', 'Kluane', 'Canada''s highest peaks and the largest non-polar icefields.',
   extensions.st_makepoint(-138.50, 60.75)::extensions.geography, '{YT}', 'CA', true),
  ('kootenay', 'Kootenay', 'Hot springs, ochre beds and Marble Canyon off Highway 93.',
   extensions.st_makepoint(-116.05, 50.87)::extensions.geography, '{BC}', 'CA', true),
  ('kouchibouguac', 'Kouchibouguac', 'Barrier dunes, lagoons and warm salt water on the Acadian coast.',
   extensions.st_makepoint(-64.95, 46.83)::extensions.geography, '{NB}', 'CA', true),
  ('la-mauricie', 'La Mauricie', 'Rolling Laurentian hills and a hundred lakes between Montreal and Quebec.',
   extensions.st_makepoint(-73.00, 46.72)::extensions.geography, '{QC}', 'CA', true),
  ('mingan-archipelago', 'Mingan Archipelago', 'Limestone monoliths carved by the sea along the St. Lawrence.',
   extensions.st_makepoint(-63.60, 50.23)::extensions.geography, '{QC}', 'CA', true),
  ('mount-revelstoke', 'Mount Revelstoke', 'A summit road into wildflower meadows above the Columbia River.',
   extensions.st_makepoint(-118.15, 51.08)::extensions.geography, '{BC}', 'CA', true),
  ('naats-ihchoh', 'Naats''ihch''oh', 'Headwaters of the Nahanni, in the Mackenzie Mountains.',
   extensions.st_makepoint(-128.30, 62.70)::extensions.geography, '{NT}', 'CA', true),
  ('nahanni', 'Nahanni', 'Virginia Falls, twice the height of Niagara, and four deep canyons.',
   extensions.st_makepoint(-125.58, 61.55)::extensions.geography, '{NT}', 'CA', true),
  ('pacific-rim', 'Pacific Rim', 'Long Beach, the West Coast Trail and old-growth rainforest.',
   extensions.st_makepoint(-125.62, 49.00)::extensions.geography, '{BC}', 'CA', true),
  ('point-pelee', 'Point Pelee', 'The southernmost tip of mainland Canada, and a migration funnel for birds.',
   extensions.st_makepoint(-82.52, 41.96)::extensions.geography, '{ON}', 'CA', true),
  ('prince-albert', 'Prince Albert', 'Boreal forest, free-ranging bison and Grey Owl''s cabin.',
   extensions.st_makepoint(-106.33, 53.97)::extensions.geography, '{SK}', 'CA', true),
  ('prince-edward-island', 'Prince Edward Island', 'Red sandstone cliffs, dunes and Green Gables shore.',
   extensions.st_makepoint(-63.08, 46.42)::extensions.geography, '{PE}', 'CA', true),
  ('pukaskwa', 'Pukaskwa', 'Wild Lake Superior coastline and boreal forest with no roads through it.',
   extensions.st_makepoint(-85.98, 48.30)::extensions.geography, '{ON}', 'CA', true),
  ('qausuittuq', 'Qausuittuq', 'High Arctic tundra and endangered Peary caribou on Bathurst Island.',
   extensions.st_makepoint(-97.00, 75.75)::extensions.geography, '{NU}', 'CA', true),
  ('quttinirpaaq', 'Quttinirpaaq', 'The top of the world on Ellesmere Island, polar desert and ice caps.',
   extensions.st_makepoint(-72.00, 82.20)::extensions.geography, '{NU}', 'CA', true),
  ('riding-mountain', 'Riding Mountain', 'An escarpment island of forest and bison above the Manitoba prairie.',
   extensions.st_makepoint(-100.05, 50.87)::extensions.geography, '{MB}', 'CA', true),
  ('sable-island', 'Sable Island', 'A crescent sandbar far offshore, home to wild horses and grey seals.',
   extensions.st_makepoint(-59.91, 43.93)::extensions.geography, '{NS}', 'CA', true),
  ('sirmilik', 'Sirmilik', 'Glaciers, seabird colonies and the floe edge on north Baffin.',
   extensions.st_makepoint(-79.00, 72.83)::extensions.geography, '{NU}', 'CA', true),
  ('terra-nova', 'Terra Nova', 'Sheltered fjords and boreal forest on Newfoundland''s east coast.',
   extensions.st_makepoint(-53.97, 48.52)::extensions.geography, '{NL}', 'CA', true),
  ('thaidene-nene', 'Thaidene Nene', 'Where boreal forest meets tundra on the East Arm of Great Slave Lake.',
   extensions.st_makepoint(-109.00, 62.50)::extensions.geography, '{NT}', 'CA', true),
  ('thousand-islands', 'Thousand Islands', 'Granite islands and channels where the St. Lawrence leaves Lake Ontario.',
   extensions.st_makepoint(-75.87, 44.40)::extensions.geography, '{ON}', 'CA', true),
  ('torngat-mountains', 'Torngat Mountains', 'Labrador''s fjords and the highest peaks in mainland eastern Canada.',
   extensions.st_makepoint(-63.80, 59.00)::extensions.geography, '{NL}', 'CA', true),
  ('tuktut-nogait', 'Tuktut Nogait', 'Canyons, waterfalls and the Bluenose West caribou herd.',
   extensions.st_makepoint(-121.00, 68.85)::extensions.geography, '{NT}', 'CA', true),
  ('ukkusiksalik', 'Ukkusiksalik', 'A tidal inland sea off Hudson Bay, with polar bears and old Inuit sites.',
   extensions.st_makepoint(-87.20, 65.33)::extensions.geography, '{NU}', 'CA', true),
  ('vuntut', 'Vuntut', 'Old Crow Flats wetlands, unglaciated and rich with waterfowl.',
   extensions.st_makepoint(-139.90, 68.30)::extensions.geography, '{YT}', 'CA', true),
  ('wapusk', 'Wapusk', 'One of the largest polar bear denning areas on earth.',
   extensions.st_makepoint(-93.35, 57.77)::extensions.geography, '{MB}', 'CA', true),
  ('waterton-lakes', 'Waterton Lakes', 'Where prairie meets mountains, joined to Glacier across the border.',
   extensions.st_makepoint(-113.90, 49.05)::extensions.geography, '{AB}', 'CA', true),
  ('wood-buffalo', 'Wood Buffalo', 'Canada''s largest national park, with the last wild whooping cranes.',
   extensions.st_makepoint(-112.99, 59.38)::extensions.geography, '{AB,NT}', 'CA', true),
  ('yoho', 'Yoho', 'Takakkaw Falls, Emerald Lake and the Burgess Shale fossils.',
   extensions.st_makepoint(-116.50, 51.40)::extensions.geography, '{BC}', 'CA', true)
on conflict (slug) do nothing;
