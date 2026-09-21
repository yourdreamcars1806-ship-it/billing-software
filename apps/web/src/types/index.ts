export type BusinessType = "clothing" | "car";
export type PaymentMethod =
  | "cash"
  | "upi"
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

export interface Customer {
  id: string;
  business_id: string;
  name: string;
  mobile: string | null;
  email: string | null;
  address: string | null;
  notes: string | null;
  is_active: boolean;
  total_billed?: number;
  total_paid?: number;
  outstanding_amount?: number;
  invoice_count?: number;
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
  car_make?: string | null;
  car_model?: string | null;
  car_variant?: string | null;
  car_registration_number?: string | null;
  car_chassis_number?: string | null;
  car_engine_number?: string | null;
  car_manufacturing_year?: number | null;
  car_color?: string | null;
  car_fuel_type?: string | null;
  customers?: Customer | null;
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

export interface ProductVariant {
  id: string;
  business_id: string;
  product_id: string;
  size: string | null;
  color: string | null;
  fabric: string | null;
  selling_price: number;
  tax_rate: number | null;
  barcode: string | null;
  barcode_format?: string;
  sku?: string | null;
  is_active?: boolean;
  products?: { name: string; brand: string | null; category?: string | null } | null;
}

export interface ClothingProductItem {
  id: string;
  business_id: string;
  name: string;
  brand: string | null;
  category: string | null;
  sub_category: string | null;
  size: string;
  color: string;
  fabric: string | null;
  selling_price: number;
  tax_rate: number;
  barcode: string;
  barcode_format: string;
  is_active: boolean;
}

export const PAYMENT_METHODS: { value: PaymentMethod; label: string }[] = [
  { value: "cash", label: "Cash" },
  { value: "upi", label: "UPI" },
  { value: "card", label: "Card" },
  { value: "bank_transfer", label: "Bank Transfer" },
  { value: "other", label: "Other" },
];

export function businessFeatures(type: BusinessType) {
  return {
    barcode: type === "clothing",
    products: type === "clothing",
    carFields: type === "car",
  };
}
