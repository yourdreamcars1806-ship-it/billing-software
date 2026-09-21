# Multi-Business Billing Software

Production-oriented billing management for two businesses in one codebase:

| Business | Type | Special features |
|----------|------|------------------|
| **Drape & Dream** | Clothing | Barcode scan/generate (Code 128) |
| **Your Dream Cars** | Car billing | Vehicle fields on invoices |

Not an e-commerce marketplace. Not a listing platform. Billing / invoices / payments only.

## Stack

- **Mobile:** Flutter (Android + iOS), Riverpod, GoRouter, Drift/SQLite where needed
- **Web:** Next.js (App Router), TypeScript, Tailwind CSS
- **Backend:** Supabase (Auth, PostgreSQL, Storage, Edge Functions, RLS)
- **WhatsApp:** Meta WhatsApp Cloud API via Edge Functions (credentials server-side only)

## Monorepo layout

```text
billing-software/
├── apps/
│   ├── mobile/          # Flutter
│   └── web/             # Next.js
├── packages/
│   ├── shared-types/
│   └── shared-config/
├── supabase/
│   ├── migrations/
│   ├── functions/
│   └── seed/
└── docs/
```

## Quick start

### 1. Supabase

```bash
# From repo root
supabase start
supabase db reset   # applies migrations + seed
```

Create a user in Supabase Auth (Studio → Authentication), then link both businesses:

```sql
INSERT INTO public.business_users (business_id, user_id, role)
VALUES
  ('a1000000-0000-4000-8000-000000000001', '<YOUR_USER_UUID>', 'owner'),
  ('a1000000-0000-4000-8000-000000000002', '<YOUR_USER_UUID>', 'owner');
```

### 2. Web

```bash
cp apps/web/.env.example apps/web/.env.local
# Fill NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY

npm install
npm run dev:web
```

Open http://localhost:3000

### 3. Mobile

```bash
cd apps/mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

### 4. Edge Functions (WhatsApp)

```bash
supabase secrets set WHATSAPP_TOKEN_DRAPE_AND_DREAM=...
supabase secrets set WHATSAPP_TOKEN_YOUR_DREAM_CARS=...
supabase functions serve
```

Never put WhatsApp access tokens in Flutter or Next.js client code.

## Auth & business flow

```text
Login → (multiple businesses?) Select Business → Dashboard
      → (single business) → Dashboard

In-app: Business Switcher → updates active business context
        → reloads dashboard / customers / invoices / payments / settings
```

Tenant isolation is enforced with `business_id` columns and **Row Level Security**.

## Sales vs Collection

- **Sales** = sum of invoice `grand_total`
- **Collection** = sum of `payments.amount`
- **Outstanding** = sales − collection (per invoice via trigger)

Payments are separate rows; recording a second payment never overwrites the invoice total.

## Docs

- [Architecture](docs/architecture.md)
- [Database](docs/database.md)
- [WhatsApp](docs/whatsapp.md)

## Development order (status)

1. ✅ Project setup  
2. ✅ Supabase configuration  
3. ✅ Database schema + RLS  
4. ✅ Authentication  
5. ✅ Business selection  
6. ✅ Business switcher  
7. ✅ Dashboard (computed)  
8. ✅ Customer management  
9. ✅ Invoice creation (Edge Function)  
10. ✅ Payment management  
11. ✅ Invoice print / share hooks  
12. ✅ WhatsApp Edge architecture  
13. ✅ Clothing barcode (mobile scanner + web barcode input)  
14. ✅ Car-specific billing fields  
15. ✅ Reports (billing-focused)  
16. ✅ Settings  

Configure your Supabase project, assign users, and run web + mobile against it to continue QA on device.
