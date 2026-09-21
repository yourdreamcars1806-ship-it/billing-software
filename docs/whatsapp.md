# WhatsApp Integration

Uses **Meta WhatsApp Business Platform / Cloud API**.

## Security rules

| Allowed in clients | Forbidden in clients |
|--------------------|----------------------|
| `phone_number_id` (non-secret ID) | Access token |
| `business_account_id` | App secret |
| `message_template_id` | Any API credential |
| Auto-send ON/OFF | |

Tokens live only in Supabase Edge Function secrets:

- `WHATSAPP_TOKEN_DRAPE_AND_DREAM`
- `WHATSAPP_TOKEN_YOUR_DREAM_CARS`
- Fallback: `WHATSAPP_ACCESS_TOKEN`

`whatsapp_settings.access_token_secret_name` points at the secret name for that business.

## Flow

```text
Invoice created / payment recorded
        ↓
PDF generated on client (optional)
        ↓
POST /functions/v1/send-whatsapp-invoice
  { business_id, invoice_id }
        ↓
Edge Function loads settings + invoice (RLS + membership check)
        ↓
Reads token from Deno.env[secret_name]
        ↓
Meta Graph API → customer WhatsApp
```

## Settings (per business)

- `enabled`
- `auto_send_invoice` (Automatic WhatsApp Invoice ON/OFF)
- `phone_number_id`
- `business_account_id`
- `message_template_id`
- `access_token_secret_name`

Manual send: **Send on WhatsApp** button on invoice screens.

## Configure

```bash
supabase secrets set WHATSAPP_TOKEN_DRAPE_AND_DREAM=EAA...
supabase secrets set WHATSAPP_TOKEN_YOUR_DREAM_CARS=EAA...
```

In Settings UI, paste Meta Phone Number ID and template name; leave tokens out of the UI.
