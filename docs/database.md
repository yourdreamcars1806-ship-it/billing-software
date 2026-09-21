# Database

## Seeded businesses

| UUID | Slug | Name |
|------|------|------|
| `a1000000-0000-4000-8000-000000000001` | `drape-and-dream` | Drape & Dream |
| `a1000000-0000-4000-8000-000000000002` | `your-dream-cars` | Your Dream Cars |

## Core tables

- `profiles` — linked to `auth.users`
- `businesses` — tenant root (`business_type`: clothing | car)
- `business_users` — user ↔ business membership
- `customers` — per business
- `products` / `product_variants` — clothing catalog + unique barcode
- `invoices` / `invoice_items` — billing
- `payments` — separate payment rows
- `business_settings` / `invoice_settings` / `whatsapp_settings`

## Views

- `dashboard_stats` — computed today sales, today collection, pending, counts
- `customer_balances` — billed / paid / outstanding per customer

## Key rules

1. Every business-owned row has `business_id`
2. `payments` never overwrite `invoices.grand_total`
3. Trigger `recalculate_invoice_payments` maintains `amount_paid`, `amount_outstanding`, `payment_status`
4. `next_invoice_number(business_id)` allocates numbers atomically
5. Clothing variants auto-generate Code 128–compatible barcodes when `enable_barcode` is true

## RLS

Authenticated users may only SELECT/INSERT/UPDATE/DELETE rows where:

```sql
public.user_has_business_access(business_id)
```

Membership comes from `business_users`.

## Linking a user after signup

```sql
INSERT INTO public.business_users (business_id, user_id, role)
SELECT b.id, '<user-uuid>', 'owner'
FROM public.businesses b
WHERE b.slug IN ('drape-and-dream', 'your-dream-cars');
```
