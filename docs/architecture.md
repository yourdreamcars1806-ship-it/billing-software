# Architecture

## Goals

- One codebase / monorepo for two businesses
- Strict tenant isolation (`business_id` + RLS)
- Shared billing engine; business-specific features are plugins/flags
- Sensitive WhatsApp credentials only on the server

## High-level diagram

```text
┌─────────────┐   ┌─────────────┐
│ Flutter App │   │  Next.js    │
│ Android/iOS │   │  Web App    │
└──────┬──────┘   └──────┬──────┘
       │                 │
       └────────┬────────┘
                │  Supabase client (anon key + user JWT)
                ▼
        ┌───────────────┐
        │   Supabase    │
        │ Auth · Postgres│
        │ Storage · RLS  │
        └───────┬───────┘
                │
        ┌───────▼────────┐
        │ Edge Functions │
        │ generate-invoice│
        │ process-payment │
        │ send-whatsapp   │──▶ Meta WhatsApp Cloud API
        └────────────────┘
```

## Active business context

After login, the client stores the selected business (Zustand on web, Riverpod on mobile).

Every repository / query includes `business_id`. Switching business:

1. Updates active business context
2. Navigates to that business dashboard
3. Reloads customers, invoices, payments, settings
4. Applies feature flags (`barcode` for clothing only)

## Feature flags

| Feature | Drape & Dream | Your Dream Cars |
|---------|---------------|-----------------|
| Barcode | Yes | No |
| Product variants | Yes | No |
| Car fields on invoice | No | Yes |
| Customers / invoices / payments | Yes | Yes |
| Dashboard sales vs collection | Yes | Yes |

Adding a third business later should only require a new `businesses` row + settings — not a rewrite of the billing engine.

## Invoice lifecycle

```text
Create draft lines (client)
        ↓
Edge: generate-invoice
  - allocate invoice number (atomic)
  - insert invoice + items
  - optional initial payment
        ↓
DB trigger recalculates amount_paid / outstanding / payment_status
        ↓
Optional auto WhatsApp (settings + Edge)
```

## Security

- RLS on all tenant tables
- `user_has_business_access(business_id)` helper
- Edge Functions verify JWT and membership before mutating
- WhatsApp tokens: Deno.env secrets referenced by `whatsapp_settings.access_token_secret_name`
