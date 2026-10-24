-- Feature completion migration. Apply after 202610240001_initial_schema.sql.
-- Public audio stays unavailable until an administrator verifies a license reference.
alter table public.artists add column if not exists website_url text;
alter table public.artists add column if not exists social_links jsonb not null default '{}'::jsonb;
alter table public.songs add column if not exists moderation_note text;
alter table public.artist_submissions add column if not exists rights_declaration text;
alter table public.music_events add column if not exists external_url text;
alter table public.music_events add column if not exists sponsored boolean not null default false;

-- Approved artists may edit profile details while retaining approved status.
create policy artists_update_approved_profile on public.artists for update to authenticated using(owner_id=auth.uid() and status='approved') with check(owner_id=auth.uid() and status='approved');
create policy albums_insert_owner on public.albums for insert to authenticated with check(status='pending' and exists(select 1 from public.artists a where a.id=artist_id and a.owner_id=auth.uid()));
create policy albums_update_owner on public.albums for update to authenticated using(exists(select 1 from public.artists a where a.id=artist_id and a.owner_id=auth.uid() and a.status in('pending','changes_requested'))) with check(status in('pending','changes_requested') and exists(select 1 from public.artists a where a.id=artist_id and a.owner_id=auth.uid()));
create policy song_sources_insert_owner on public.song_sources for insert to authenticated with check(provider in('youtube','official_link') and exists(select 1 from public.songs s join public.artists a on a.id=s.artist_id where s.id=song_id and a.owner_id=auth.uid() and s.status in('pending','changes_requested')));
create policy song_sources_update_admin on public.song_sources for update to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));
create policy song_sources_delete_admin on public.song_sources for delete to authenticated using(public.has_role('admin'));
create policy countries_admin on public.countries for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));
create policy genres_admin on public.genres for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));

-- Replace playlist entry policies to ensure only approved songs can be exposed in public playlists.
drop policy if exists playlist_songs_read on public.playlist_songs;
drop policy if exists playlist_songs_write on public.playlist_songs;
create policy playlist_songs_read on public.playlist_songs for select to anon,authenticated using(exists(select 1 from public.playlists p join public.songs s on s.id=playlist_songs.song_id where p.id=playlist_id and s.status='approved' and (p.is_public or p.owner_id=auth.uid() or public.has_role('admin'))));
create policy playlist_songs_write on public.playlist_songs for all to authenticated using(exists(select 1 from public.playlists p where p.id=playlist_id and p.owner_id=auth.uid())) with check(exists(select 1 from public.playlists p join public.songs s on s.id=playlist_songs.song_id where p.id=playlist_id and p.owner_id=auth.uid() and s.status='approved'));

-- Atomic artist submission: an affirmative rights declaration is mandatory and the record is always pending review.
create or replace function public.submit_artist_song(p_artist_id uuid,p_title text,p_country_id text,p_genre_id uuid,p_youtube_video_id text,p_official_url text,p_rights_declaration text)
returns uuid language plpgsql security invoker set search_path=public as $$
declare new_song uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not exists(select 1 from public.artists where id=p_artist_id and owner_id=auth.uid()) then raise exception 'Artist profile not found'; end if;
 if length(trim(p_title)) not between 1 and 160 then raise exception 'Title must be 1 to 160 characters'; end if;
 if p_rights_declaration is null or length(trim(p_rights_declaration))<20 or length(p_rights_declaration)>1000 then raise exception 'A complete rights declaration is required'; end if;
 if coalesce(p_youtube_video_id,'') !~ '^[A-Za-z0-9_-]{11}$' and (p_official_url is null or p_official_url !~ '^https://') then raise exception 'Provide an official YouTube video ID or HTTPS source'; end if;
 insert into public.songs(artist_id,title,country_id,genre_id,status) values(p_artist_id,trim(p_title),p_country_id,p_genre_id,'pending') returning id into new_song;
 if coalesce(p_youtube_video_id,'') ~ '^[A-Za-z0-9_-]{11}$' then insert into public.song_sources(song_id,provider,provider_id,external_url,is_embeddable) values(new_song,'youtube',p_youtube_video_id,'https://www.youtube.com/watch?v='||p_youtube_video_id,true); end if;
 if p_official_url is not null and p_official_url ~ '^https://' then insert into public.song_sources(song_id,provider,external_url) values(new_song,'official_link',p_official_url); end if;
 insert into public.artist_submissions(artist_id,song_id,declaration_accepted_at,rights_declaration,status) values(p_artist_id,new_song,now(),trim(p_rights_declaration),'pending');
 return new_song;
end $$;
grant execute on function public.submit_artist_song(uuid,text,text,uuid,text,text,text) to authenticated;

-- Artwork is public, limited to modest image files. Audio bucket remains private and has no client upload policy.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('artist-artwork','artist-artwork',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('licensed-audio','licensed-audio',false,52428800,array['audio/mpeg','audio/mp4','audio/aac','audio/ogg','audio/wav']) on conflict(id) do update set public=false,file_size_limit=52428800,allowed_mime_types=array['audio/mpeg','audio/mp4','audio/aac','audio/ogg','audio/wav'];
create policy artwork_public_read on storage.objects for select to anon,authenticated using(bucket_id='artist-artwork');
create policy artwork_owner_upload on storage.objects for insert to authenticated with check(bucket_id='artist-artwork' and (storage.foldername(name))[1]=auth.uid()::text and lower(storage.extension(name)) in('jpg','jpeg','png','webp') and coalesce((metadata->>'size')::bigint,0)<=5242880 and metadata->>'mimetype' in('image/jpeg','image/png','image/webp'));
create policy artwork_owner_update on storage.objects for update to authenticated using(bucket_id='artist-artwork' and (storage.foldername(name))[1]=auth.uid()::text) with check(bucket_id='artist-artwork' and (storage.foldername(name))[1]=auth.uid()::text and lower(storage.extension(name)) in('jpg','jpeg','png','webp') and coalesce((metadata->>'size')::bigint,0)<=5242880);
create policy artwork_owner_delete on storage.objects for delete to authenticated using(bucket_id='artist-artwork' and (storage.foldername(name))[1]=auth.uid()::text);
-- No policy allows users to upload licensed audio. Admin service-side workflows must attach verified rights first.
-- Account deletion preserves compliance records and removes personal identifiers.
alter table public.artists alter column owner_id drop not null;
alter table public.artists drop constraint if exists artists_owner_id_fkey;
alter table public.artists add constraint artists_owner_id_fkey foreign key(owner_id) references auth.users(id) on delete set null;
alter table public.music_events alter column organizer_id drop not null;
alter table public.music_events drop constraint if exists music_events_organizer_id_fkey;
alter table public.music_events add constraint music_events_organizer_id_fkey foreign key(organizer_id) references auth.users(id) on delete set null;
alter table public.payment_transactions alter column user_id drop not null;
alter table public.payment_transactions drop constraint if exists payment_transactions_user_id_fkey;
alter table public.payment_transactions add constraint payment_transactions_user_id_fkey foreign key(user_id) references auth.users(id) on delete set null;
alter table public.payment_transactions drop constraint if exists payment_transactions_check;
alter table public.payment_transactions add constraint payment_transactions_target_check check(campaign_id is not null or subscription_id is not null or user_id is null);
alter table public.payment_transactions drop constraint if exists payment_transactions_subscription_id_fkey;
alter table public.payment_transactions add constraint payment_transactions_subscription_id_fkey foreign key(subscription_id) references public.subscriptions(id) on delete set null;
alter table public.artist_submissions drop constraint if exists artist_submissions_reviewer_id_fkey;
alter table public.artist_submissions add constraint artist_submissions_reviewer_id_fkey foreign key(reviewer_id) references auth.users(id) on delete set null;
alter table public.playlist_songs drop constraint if exists playlist_songs_position_check;
alter table public.playlist_songs add constraint playlist_songs_position_check check(position>=0);

create or replace function public.add_song_to_playlist(p_playlist uuid,p_song uuid) returns void language plpgsql security invoker set search_path=public as $$
declare next_position integer;
begin
 perform 1 from public.playlists where id=p_playlist and owner_id=auth.uid() for update;
 if not found then raise exception 'Playlist not found'; end if;
 select coalesce(max(position)+1,0) into next_position from public.playlist_songs where playlist_id=p_playlist;
 insert into public.playlist_songs(playlist_id,song_id,position) values(p_playlist,p_song,next_position);
end $$;
grant execute on function public.add_song_to_playlist(uuid,uuid) to authenticated;

create or replace function public.reorder_playlist_song(p_playlist uuid,p_song uuid,p_new_position integer) returns void language plpgsql security invoker set search_path=public as $$
declare ids uuid[]; target integer; offset_value integer; i integer;
begin
 perform 1 from public.playlists where id=p_playlist and owner_id=auth.uid() for update;
 if not found then raise exception 'Playlist not found'; end if;
 select array_agg(song_id order by position) into ids from public.playlist_songs where playlist_id=p_playlist;
 if ids is null or not (p_song=any(ids)) then raise exception 'Song not found in playlist'; end if;
 ids:=array_remove(ids,p_song);target:=greatest(0,least(p_new_position,coalesce(cardinality(ids),0)));ids:=ids[1:target]||p_song||ids[target+1:cardinality(ids)];
 select coalesce(max(position),0)+cardinality(ids)+1 into offset_value from public.playlist_songs where playlist_id=p_playlist;
 update public.playlist_songs set position=position+offset_value where playlist_id=p_playlist;
 for i in 1..cardinality(ids) loop update public.playlist_songs set position=i-1 where playlist_id=p_playlist and song_id=ids[i];end loop;
end $$;
grant execute on function public.reorder_playlist_song(uuid,uuid,integer) to authenticated;

create or replace function public.remove_song_from_playlist(p_playlist uuid,p_song uuid) returns void language plpgsql security invoker set search_path=public as $$
begin
 if not exists(select 1 from public.playlists where id=p_playlist and owner_id=auth.uid()) then raise exception 'Playlist not found'; end if;
 delete from public.playlist_songs where playlist_id=p_playlist and song_id=p_song;
end $$;
grant execute on function public.remove_song_from_playlist(uuid,uuid) to authenticated;
-- Keep billing audit records after user deletion; null the account owner but retain the subscription and transaction relation.
alter table public.subscriptions alter column user_id drop not null;
alter table public.subscriptions drop constraint if exists subscriptions_user_id_fkey;
alter table public.subscriptions add constraint subscriptions_user_id_fkey foreign key(user_id) references auth.users(id) on delete set null;
alter table public.payment_transactions drop constraint if exists payment_transactions_target_check;
alter table public.payment_transactions add constraint payment_transactions_target_check check((campaign_id is null) <> (subscription_id is null));
alter table public.payment_transactions drop constraint if exists payment_transactions_subscription_id_fkey;
alter table public.payment_transactions add constraint payment_transactions_subscription_id_fkey foreign key(subscription_id) references public.subscriptions(id);
create or replace function public.review_artist_song(p_song_id uuid,p_status public.publication_status,p_note text default null) returns void language plpgsql security invoker set search_path=public as $$
begin
 if not public.has_role('admin') then raise exception 'Administrator role required'; end if;
 if p_status not in('approved','rejected','changes_requested') then raise exception 'Invalid review status'; end if;
 update public.songs set status=p_status,moderation_note=nullif(left(trim(coalesce(p_note,'')),1000),'') where id=p_song_id;
 if not found then raise exception 'Submission not found'; end if;
 update public.artist_submissions set status=p_status,reviewer_id=auth.uid(),reviewer_note=nullif(left(trim(coalesce(p_note,'')),1000),''),reviewed_at=now() where song_id=p_song_id;
end $$;
grant execute on function public.review_artist_song(uuid,public.publication_status,text) to authenticated;
create policy active_sponsored_campaigns_read on public.promotional_campaigns for select to anon,authenticated using(status='active' and coalesce(starts_at,now())<=now() and (ends_at is null or ends_at>=now()) and exists(select 1 from public.artists a where a.id=artist_id and a.status='approved'));
