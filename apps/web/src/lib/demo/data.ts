import type {
  Business,
  Customer,
  DashboardStats,
  Invoice,
  Payment,
  ClothingProductItem,
} from "@/types";
import {
  generateClothingBarcode,
  nextSequenceFromBarcodes,
} from "@/lib/barcode";

/** Only true when explicitly enabled — otherwise app uses real Supabase data */
export const DEMO_MODE = process.env.NEXT_PUBLIC_DEMO_MODE === "true";

export const DEMO_COOKIE = "billing_demo_session";
/** Locked business slug after login — no switching allowed */
export const DEMO_BUSINESS_COOKIE = "billing_locked_business";

/** Default login per business (clothing + cars separate accounts) */
export const BUSINESS_LOGINS: Record<
  string,
  { email: string; password: string }
> = {
  "drape-and-dream": {
    email: "drapedream@gmail.com",
    password: "Gafru@786",
  },
  "your-dream-cars": {
    email: "yourdreamcars1806@gmail.com",
    password: "Gafru@786",
  },
};

export function getBusinessLogin(slug: string) {
  return (
    BUSINESS_LOGINS[slug] ?? {
      email: "",
      password: "",
    }
  );
}

/** @deprecated use getBusinessLogin(slug) */
export const DEMO_CREDENTIALS = BUSINESS_LOGINS["drape-and-dream"];

export const DEMO_BUSINESSES: Business[] = [
  {
    id: "a1000000-0000-4000-8000-000000000001",
    slug: "drape-and-dream",
    name: "Drape & Dream",
    business_type: "clothing",
    description: "Clothing Billing",
    logo_url: "/images/drape-and-dream-logo.png",
    address: "NIBM Clover Hills Plaza, Office No. 79, Pune",
    phone: "+91 98765 00001",
    email: "drapedream@gmail.com",
    gstin: "27AAAAA0000A1Z5",
    pan: "AAAAA0000A",
    is_active: true,
  },
  {
    id: "a1000000-0000-4000-8000-000000000002",
    slug: "your-dream-cars",
    name: "Your Dream Cars",
    business_type: "car",
    description: "Car Billing",
    logo_url: "/images/your-dream-cars-logo.png",
    address: "NIBM Clover Hills Plaza, Office No. 80, Pune",
    phone: "+91 98765 00002",
    email: "yourdreamcars1806@gmail.com",
    gstin: "27BBBBB0000B1Z5",
    pan: "BBBBB0000B",
    is_active: true,
  },
];

export function getDemoBusiness(slug: string): Business | undefined {
  return DEMO_BUSINESSES.find((b) => b.slug === slug);
}

export function getDemoStats(businessId: string): DashboardStats {
  const clothing = businessId === DEMO_BUSINESSES[0].id;
  return {
    business_id: businessId,
    today_sales: clothing ? 24800 : 485000,
    today_collection: clothing ? 18500 : 250000,
    pending_amount: clothing ? 12450 : 235000,
    total_invoices: clothing ? 42 : 18,
    paid_invoices: clothing ? 28 : 10,
    partial_invoices: clothing ? 9 : 5,
    pending_invoices: clothing ? 5 : 3,
  };
}

export function getDemoCustomers(businessId: string): Customer[] {
  return [
    {
      id: "c1",
      business_id: businessId,
      name: "Rahul Sharma",
      mobile: "9876543210",
      email: "rahul@example.com",
      address: "Andheri West, Mumbai",
      notes: null,
      is_active: true,
      total_billed: 18500,
      total_paid: 15000,
      outstanding_amount: 3500,
      invoice_count: 4,
    },
    {
      id: "c2",
      business_id: businessId,
      name: "Priya Patel",
      mobile: "9123456780",
      email: "priya@example.com",
      address: "Bandra, Mumbai",
      notes: null,
      is_active: true,
      total_billed: 9200,
      total_paid: 9200,
      outstanding_amount: 0,
      invoice_count: 2,
    },
    {
      id: "c3",
      business_id: businessId,
      name: "Amit Verma",
      mobile: "9988776655",
      email: null,
      address: "Pune",
      notes: null,
      is_active: true,
      total_billed: 45000,
      total_paid: 20000,
      outstanding_amount: 25000,
      invoice_count: 1,
    },
  ];
}

export function getDemoInvoices(businessId: string): Invoice[] {
  const today = new Date().toISOString().slice(0, 10);
  return [
    {
      id: "inv1",
      business_id: businessId,
      customer_id: "c1",
      invoice_number:
        businessId === DEMO_BUSINESSES[0].id ? "DD-00042" : "YDC-00018",
      invoice_date: today,
      status: "issued",
      payment_status: "partial",
      subtotal: 10000,
      discount_amount: 500,
      tax_amount: 1140,
      additional_charges: 0,
      grand_total: 10640,
      amount_paid: 5000,
      amount_outstanding: 5640,
      notes: null,
      customers: {
        id: "c1",
        business_id: businessId,
        name: "Rahul Sharma",
        mobile: "9876543210",
        email: null,
        address: null,
        notes: null,
        is_active: true,
      },
    },
    {
      id: "inv2",
      business_id: businessId,
      customer_id: "c2",
      invoice_number:
        businessId === DEMO_BUSINESSES[0].id ? "DD-00041" : "YDC-00017",
      invoice_date: today,
      status: "issued",
      payment_status: "paid",
      subtotal: 4500,
      discount_amount: 0,
      tax_amount: 540,
      additional_charges: 0,
      grand_total: 5040,
      amount_paid: 5040,
      amount_outstanding: 0,
      notes: null,
      customers: {
        id: "c2",
        business_id: businessId,
        name: "Priya Patel",
        mobile: "9123456780",
        email: null,
        address: null,
        notes: null,
        is_active: true,
      },
    },
    {
      id: "inv3",
      business_id: businessId,
      customer_id: "c3",
      invoice_number:
        businessId === DEMO_BUSINESSES[0].id ? "DD-00040" : "YDC-00016",
      invoice_date: today,
      status: "issued",
      payment_status: "pending",
      subtotal: 8000,
      discount_amount: 0,
      tax_amount: 960,
      additional_charges: 200,
      grand_total: 9160,
      amount_paid: 0,
      amount_outstanding: 9160,
      notes: null,
      customers: {
        id: "c3",
        business_id: businessId,
        name: "Amit Verma",
        mobile: "9988776655",
        email: null,
        address: null,
        notes: null,
        is_active: true,
      },
    },
  ];
}

export function getDemoPayments(businessId: string): Payment[] {
  const today = new Date().toISOString().slice(0, 10);
  return [
    {
      id: "p1",
      business_id: businessId,
      invoice_id: "inv1",
      amount: 5000,
      payment_date: today,
      payment_method: "upi",
      reference_number: "UPI123456",
      notes: null,
    },
    {
      id: "p2",
      business_id: businessId,
      invoice_id: "inv2",
      amount: 5040,
      payment_date: today,
      payment_method: "cash",
      reference_number: null,
      notes: null,
    },
  ];
}

const DEMO_PRODUCTS_KEY = "billing_demo_clothing_products";

const SEED_PRODUCTS: Omit<ClothingProductItem, "business_id">[] = [
  {
    id: "pv1",
    name: "Oxford Cotton Shirt",
    brand: "Drape",
    category: "Shirts",
    sub_category: "Formal",
    size: "M",
    color: "Black",
    fabric: "Cotton",
    selling_price: 1499,
    tax_rate: 12,
    barcode: "DD2603000001",
    barcode_format: "CODE128",
    is_active: true,
  },
  {
    id: "pv2",
    name: "Oxford Cotton Shirt",
    brand: "Drape",
    category: "Shirts",
    sub_category: "Formal",
    size: "L",
    color: "Black",
    fabric: "Cotton",
    selling_price: 1499,
    tax_rate: 12,
    barcode: "DD2603000002",
    barcode_format: "CODE128",
    is_active: true,
  },
  {
    id: "pv3",
    name: "Oxford Cotton Shirt",
    brand: "Drape",
    category: "Shirts",
    sub_category: "Formal",
    size: "M",
    color: "White",
    fabric: "Cotton",
    selling_price: 1499,
    tax_rate: 12,
    barcode: "DD2603000003",
    barcode_format: "CODE128",
    is_active: true,
  },
  {
    id: "pv4",
    name: "Slim Fit Chinos",
    brand: "Dreamwear",
    category: "Trousers",
    sub_category: "Casual",
    size: "32",
    color: "Navy",
    fabric: "Cotton blend",
    selling_price: 2199,
    tax_rate: 12,
    barcode: "DD2603000004",
    barcode_format: "CODE128",
    is_active: true,
  },
  {
    id: "pv5",
    name: "Linen Kurta",
    brand: "Drape",
    category: "Ethnic",
    sub_category: "Kurta",
    size: "XL",
    color: "Beige",
    fabric: "Linen",
    selling_price: 1899,
    tax_rate: 5,
    barcode: "DD2603000005",
    barcode_format: "CODE128",
    is_active: true,
  },
];

export function getDemoClothingProducts(
  businessId: string,
): ClothingProductItem[] {
  if (typeof window === "undefined") {
    return SEED_PRODUCTS.map((p) => ({ ...p, business_id: businessId }));
  }

  try {
    const raw = localStorage.getItem(DEMO_PRODUCTS_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as ClothingProductItem[];
      if (Array.isArray(parsed) && parsed.length) {
        return parsed.filter((p) => p.business_id === businessId);
      }
    }
  } catch {
    // ignore
  }

  const seeded = SEED_PRODUCTS.map((p) => ({ ...p, business_id: businessId }));
  localStorage.setItem(DEMO_PRODUCTS_KEY, JSON.stringify(seeded));
  return seeded;
}

export function saveDemoClothingProducts(products: ClothingProductItem[]) {
  if (typeof window === "undefined") return;
  localStorage.setItem(DEMO_PRODUCTS_KEY, JSON.stringify(products));
}

export function findDemoProductByBarcode(
  businessId: string,
  barcode: string,
): ClothingProductItem | undefined {
  const code = barcode.trim().toUpperCase();
  return getDemoClothingProducts(businessId).find(
    (p) => p.barcode.toUpperCase() === code && p.is_active,
  );
}

export function addDemoClothingProduct(
  businessId: string,
  input: {
    name: string;
    brand?: string;
    category?: string;
    sub_category?: string;
    size: string;
    color: string;
    fabric?: string;
    selling_price: number;
    tax_rate: number;
  },
): ClothingProductItem {
  const existing = getDemoClothingProducts(businessId);
  const seq = nextSequenceFromBarcodes(existing.map((p) => p.barcode));
  const barcode = generateClothingBarcode(seq);

  const item: ClothingProductItem = {
    id: `pv-${Date.now()}`,
    business_id: businessId,
    name: input.name.trim(),
    brand: input.brand?.trim() || null,
    category: input.category?.trim() || null,
    sub_category: input.sub_category?.trim() || null,
    size: input.size.trim(),
    color: input.color.trim(),
    fabric: input.fabric?.trim() || null,
    selling_price: input.selling_price,
    tax_rate: input.tax_rate,
    barcode,
    barcode_format: "CODE128",
    is_active: true,
  };

  saveDemoClothingProducts([item, ...existing]);
  return item;
}

export function deleteDemoClothingProduct(
  businessId: string,
  productId: string,
): void {
  const existing = getDemoClothingProducts(businessId);
  saveDemoClothingProducts(
    existing.map((p) =>
      p.id === productId ? { ...p, is_active: false } : p,
    ),
  );
}

export function deleteDemoClothingProducts(
  businessId: string,
  productIds: string[],
): void {
  const ids = new Set(productIds);
  const existing = getDemoClothingProducts(businessId);
  saveDemoClothingProducts(
    existing.map((p) => (ids.has(p.id) ? { ...p, is_active: false } : p)),
  );
}
