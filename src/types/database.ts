/**
 * Row types for the Landmarks schema.
 *
 * Kept in sync by hand with `supabase/migrations`. Timestamps come back from
 * PostgREST as ISO strings.
 */

export type LandmarkCategory =
  | 'monument'
  | 'museum'
  | 'park'
  | 'viewpoint'
  | 'building'
  | 'natural'
  | 'other';

export type VisitVisibility = 'public' | 'followers' | 'private';

export type Profile = {
  id: string;
  username: string;
  display_name: string | null;
  bio: string | null;
  /** Object path inside the `avatars` bucket, not a full URL. */
  avatar_url: string | null;
  home_city: string | null;
  follower_count: number;
  following_count: number;
  visit_count: number;
  created_at: string;
  updated_at: string;
};

export type ProfileUpdate = Partial<
  Pick<Profile, 'username' | 'display_name' | 'bio' | 'avatar_url' | 'home_city'>
>;

/**
 * `location` is a PostGIS geography column. PostgREST returns it as a WKB hex
 * string, so read coordinates through `landmarks_nearby` rather than the
 * column itself.
 */
export type Landmark = {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  category: LandmarkCategory;
  address: string | null;
  city: string | null;
  country_code: string | null;
  cover_photo_url: string | null;
  created_by: string | null;
  is_verified: boolean;
  created_at: string;
};

/** Return shape of the `landmarks_nearby` RPC. */
export type NearbyLandmark = Pick<
  Landmark,
  'id' | 'slug' | 'name' | 'category' | 'city' | 'cover_photo_url'
> & {
  distance_meters: number;
};

export type NearbyLandmarksArgs = {
  lat: number;
  lng: number;
  radius_meters?: number;
  max_results?: number;
};

export type Visit = {
  id: string;
  user_id: string;
  landmark_id: string;
  visited_at: string;
  note: string | null;
  /** Object path inside the `visit-photos` bucket. */
  photo_url: string | null;
  rating: number | null;
  visibility: VisitVisibility;
  like_count: number;
  comment_count: number;
  created_at: string;
};

export type VisitInsert = Pick<Visit, 'user_id' | 'landmark_id'> &
  Partial<Pick<Visit, 'visited_at' | 'note' | 'photo_url' | 'rating' | 'visibility'>>;

export type Follow = {
  follower_id: string;
  followee_id: string;
  created_at: string;
};

export type VisitLike = {
  visit_id: string;
  user_id: string;
  created_at: string;
};

export type VisitComment = {
  id: string;
  visit_id: string;
  user_id: string;
  body: string;
  created_at: string;
};

export type BadgeCriteria =
  | { type: 'visit_count'; count: number }
  | { type: 'category_count'; category: LandmarkCategory; count: number }
  | { type: 'city_count'; city: string; count: number }
  | { type: 'landmark'; slug: string };

export type Badge = {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  /** SF Symbol name. */
  icon: string | null;
  criteria: BadgeCriteria;
  created_at: string;
};

export type UserBadge = {
  user_id: string;
  badge_id: string;
  earned_at: string;
};

/** A check-in joined with its landmark and author, the shape the feed renders. */
export type FeedVisit = Visit & {
  landmark: Landmark;
  author: Profile;
};
