/** Shared domain types for web + documentation alignment */

export type BusinessType = "clothing" | "car";
export type PaymentMethod =
  | "cash"
  | "upi"
  | "upi_cash"
  | "card"
  | "bank_transfer"
  | "other";
export type PaymentStatus = "paid" | "partial" | "pending";
export type InvoiceStatus = "draft" | "issued" | "cancelled";

export interface Business {
  id: string;
  slug: string;
  name: string;
  business_type: BusinessType;
  description: string | null;
  logo_url: string | null;
  address: string | null;
  phone: string | null;
  email: string | null;
  gstin: string | null;
  pan: string | null;
  is_active: boolean;
}

export interface Profile {
  id: string;
  email: string;
  full_name: string | null;
  avatar_url: string | null;
  remember_session: boolean;
}

export interface BusinessUser {
  id: string;
  business_id: string;
  user_id: string;
  role: "owner" | "admin" | "staff";
  is_active: boolean;
  businesses?: Business;
}

export interface Customer {
  id: string;
  business_id: string;
  name: string;
  mobile: string | null;
  email: string | null;
  address: string | null;
  notes: string | null;
  is_active: boolean;
}

export interface Product {
  id: string;
  business_id: string;
  name: string;
  brand: string | null;
  category: string | null;
  sub_category: string | null;
  description: string | null;
  image_url: string | null;
  base_price: number;
  tax_rate: number;
  is_active: boolean;
}

export interface ProductVariant {
  id: string;
  business_id: string;
  product_id: string;
  sku: string | null;
  size: string | null;
  color: string | null;
  fabric: string | null;
  selling_price: number;
  cost_price?: number;
  tax_rate: number | null;
  offer_percent?: number;
  stock_qty?: number;
  stock_in_total?: number;
  stock_out_total?: number;
  barcode: string | null;
  barcode_format: string;
  image_url: string | null;
  is_active: boolean;
}

export interface Invoice {
  id: string;
  business_id: string;
  customer_id: string | null;
  invoice_number: string;
  invoice_date: string;
  status: InvoiceStatus;
  payment_status: PaymentStatus;
  subtotal: number;
  discount_amount: number;
  tax_amount: number;
  additional_charges: number;
  grand_total: number;
  amount_paid: number;
  amount_outstanding: number;
  notes: string | null;
  car_make: string | null;
  car_model: string | null;
  car_variant: string | null;
  car_registration_number: string | null;
  car_chassis_number: string | null;
  car_engine_number: string | null;
  car_manufacturing_year: number | null;
  car_color: string | null;
  car_fuel_type: string | null;
}

export interface InvoiceItem {
  id: string;
  business_id: string;
  invoice_id: string;
  product_id: string | null;
  product_variant_id: string | null;
  description: string;
  quantity: number;
  unit_price: number;
  discount_amount: number;
  tax_rate: number;
  tax_amount: number;
  line_total: number;
  size: string | null;
  color: string | null;
  barcode: string | null;
  sort_order: number;
}

export interface Payment {
  id: string;
  business_id: string;
  invoice_id: string;
  amount: number;
  payment_date: string;
  payment_method: PaymentMethod;
  reference_number: string | null;
  notes: string | null;
}

export interface DashboardStats {
  business_id: string;
  today_sales: number;
  today_collection: number;
  pending_amount: number;
  total_invoices: number;
  paid_invoices: number;
  partial_invoices: number;
  pending_invoices: number;
}

export interface WhatsAppSettings {
  id: string;
  business_id: string;
  enabled: boolean;
  auto_send_invoice: boolean;
  phone_number_id: string | null;
  business_account_id: string | null;
  message_template_id: string | null;
  access_token_secret_name: string | null;
}

export const BUSINESS_SLUGS = {
  DRAPE_AND_DREAM: "drape-and-dream",
  YOUR_DREAM_CARS: "your-dream-cars",
} as const;

export const PAYMENT_METHODS: { value: PaymentMethod; label: string }[] = [
  { value: "cash", label: "Cash" },
  { value: "upi", label: "UPI" },
  { value: "upi_cash", label: "UPI + Cash" },
  { value: "card", label: "Card" },
  { value: "bank_transfer", label: "Bank Transfer" },
  { value: "other", label: "Other" },
];
