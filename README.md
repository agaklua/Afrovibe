# Sauti

African-first music discovery and streaming foundation built with Next.js 16, React 19, TypeScript, Tailwind CSS 4, Supabase, and the official YouTube Data API. This workspace contains a new application scaffold.

## Included

- Responsive discovery page with country and genre browsing, search, saves, sponsored placements, and upcoming events.
- Clearly labelled preview catalog when no database is connected; approved artist and song catalog when Supabase is configured.
- Supabase email registration, sign-in, sign-out, verification callback, password recovery, account editing, and account deletion.
- Artist portal for profile creation/editing, artwork upload, rights-declared song submissions, and submission status.
- Admin review queues for artists, songs, events, reports, and copyright notices; chart management; campaign creation; and read-only account/payment records.
- Playlists with public/private visibility, approved song management, ordering, and shareable pages; favourites persist for signed-in users.
- Country and global charts, artist profiles, event submissions, reporting flows, sponsored campaign display, and API endpoints for catalog, events, promotions, favourites, and licensed audio.
- YouTube search is server-side, keeps the API key private, requests embeddable videos, and uses the official iframe player. The app does not extract YouTube audio.
- Licensed audio is served only for approved songs with verified license metadata from a private Supabase Storage bucket. Client upload is not enabled.
- SQL migrations for roles, RLS, catalogs, profiles, playlists, moderation, artwork storage, events, reports, charts, promotion, subscriptions, and audit-friendly payment records.
- SEO metadata, sitemap, robots, privacy and terms starter pages.

## Local setup

1. Use Node 20.9+ and run `npm install`.
2. Copy `.env.example` to `.env.local` and set `NEXT_PUBLIC_SITE_URL`.
3. Create a Supabase project and set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
4. Apply migrations in order: `supabase/migrations/202610240001_initial_schema.sql`, then `supabase/migrations/202610250001_platform_features.sql`. Verify them in Supabase; files in this repository do not configure a remote database.
5. Set `SUPABASE_SERVICE_ROLE_KEY` on the server only. It is used for account deletion and authorized private licensed-audio delivery. Never prefix it with `NEXT_PUBLIC_` or expose it to browser code.
6. In Supabase Auth, configure site URLs, redirect URLs, and email delivery. Register and verify an account, then grant the first admin role in Supabase SQL Editor using the commented statement at the bottom of the initial migration. Public registration cannot grant admin.
7. Set a restricted `YOUTUBE_API_KEY` server-side to enable YouTube search.
8. Run `npm run dev`. Run `npm run lint`, `npm run typecheck`, and `npm run build` for local verification.

## Rights and payments

Artist song submissions require an affirmative rights declaration and remain pending until reviewed. YouTube and official links are external sources; they do not grant this platform audio rights. The licensed-audio bucket is private, and streaming requires an administrator to verify a license and attach authorized audio through a trusted server-side workflow. No public/client audio upload flow is provided.

The schema includes subscriptions, campaigns, and payment audit records, and admins can manage sponsored campaign metadata. No payment processor, payout flow, ad network, or webhook is connected. Keep charging disabled until a provider, country/currency coverage, business/legal requirements, credentials, and signed webhook verification are implemented and reviewed.

## Deployment

Push the project to a repository and import it into Vercel or another Next.js host. Set production environment variables, configure matching Supabase Auth redirect URLs, apply and verify both migrations, and deploy. Do not commit `.env.local` or provider secrets. Test account recovery and deletion, artist moderation, storage policies, and licensed playback in a configured staging project before public launch.

## Current external requirements

This workspace has no connected Supabase project, YouTube key, verified music licenses, payment processor, advertising network, or deployment account. Database-backed flows require Supabase setup; YouTube search requires an API key; licensed streaming requires a verified license and trusted server-side audio attachment. Privacy and terms pages are starter copy and need jurisdiction-specific legal review before launch. Analytics and native Expo/mobile clients are not included.
