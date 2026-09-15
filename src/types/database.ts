/**
 * Row types for the Landmarks schema.
 *
 * Kept in sync by hand with `supabase/migrations`. Timestamps come back from
 * PostgREST as ISO strings.
 */

export type PostVisibility = 'public' | 'followers' | 'private';

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
  post_count: number;
  created_at: string;
  updated_at: string;
};

export type ProfileUpdate = Partial<
  Pick<Profile, 'username' | 'display_name' | 'bio' | 'avatar_url' | 'home_city'>
>;

/**
 * One of the 63 US national parks. `location` is a PostGIS geography column,
 * which PostgREST returns as a WKB hex string, so read coordinates through the
 * `parks_nearby` RPC rather than the column itself.
 */
export type Park = {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  /** Two-letter codes; a few parks span several states. */
  state_codes: string[];
  address: string | null;
  cover_photo_url: string | null;
  created_by: string | null;
  is_verified: boolean;
  created_at: string;
};

/** Return shape of the `parks_nearby` RPC. */
export type NearbyPark = Pick<
  Park,
  'id' | 'slug' | 'name' | 'state_codes' | 'cover_photo_url'
> & {
  distance_meters: number;
};

export type NearbyParksArgs = {
  lat: number;
  lng: number;
  radius_meters?: number;
  max_results?: number;
};

export type Post = {
  id: string;
  user_id: string;
  park_id: string;
  taken_at: string;
  caption: string | null;
  /** Object path inside the `post-photos` bucket. Every post has a photo. */
  photo_url: string;
  rating: number | null;
  visibility: PostVisibility;
  like_count: number;
  comment_count: number;
  created_at: string;
};

/**
 * Creating a post. `location` is the exact spot the photo was taken, which can
 * be far from the park's center pin; omit it to fall back to `parks.location`.
 */
export type PostInsert = Pick<Post, 'user_id' | 'park_id' | 'photo_url'> &
  Partial<Pick<Post, 'taken_at' | 'caption' | 'rating' | 'visibility'>> & {
    location?: { lat: number; lng: number };
  };

export type Follow = {
  follower_id: string;
  followee_id: string;
  created_at: string;
};

export type PostLike = {
  post_id: string;
  user_id: string;
  created_at: string;
};

export type PostComment = {
  id: string;
  post_id: string;
  user_id: string;
  body: string;
  created_at: string;
};

export type BadgeCriteria =
  | { type: 'post_count'; count: number }
  | { type: 'park_count'; count: number }
  | { type: 'state_count'; count: number }
  | { type: 'park'; slug: string };

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

/** A post joined with its park and author, the shape the feed renders. */
export type FeedPost = Post & {
  park: Park;
  author: Profile;
};
