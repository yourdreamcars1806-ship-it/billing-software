import {
  DEMO_MODE,
  getDemoClothingProducts,
} from "@/lib/demo/data";
import { createClient } from "@/lib/supabase/client";
import { CLOTHING_CATEGORIES } from "@/features/products/categories";

export type CategoryStockRow = {
  category: string;
  inStockPcs: number;
  inStockItems: number;
  outOfStockItems: number;
  buyValue: number;
  sellValue: number;
  soldPcs: number;
  soldValue: number;
};

export type StockOverview = {
  totals: {
    inStockPcs: number;
    inStockItems: number;
    outOfStockItems: number;
    buyValue: number;
    sellValue: number;
    soldPcs: number;
    soldValue: number;
  };
  categories: CategoryStockRow[];
};

function emptyTotals() {
  return {
    inStockPcs: 0,
    inStockItems: 0,
    outOfStockItems: 0,
    buyValue: 0,
    sellValue: 0,
    soldPcs: 0,
    soldValue: 0,
  };
}

export function summarizeFromRows(
  rows: {
    category: string | null;
    stock_qty: number;
    cost_price: number;
    selling_price: number;
    stock_out_total?: number;
  }[],
): StockOverview {
  const map = new Map<string, CategoryStockRow>();

  for (const cat of CLOTHING_CATEGORIES) {
    map.set(cat, {
      category: cat,
      inStockPcs: 0,
      inStockItems: 0,
      outOfStockItems: 0,
      buyValue: 0,
      sellValue: 0,
      soldPcs: 0,
      soldValue: 0,
    });
  }

  for (const row of rows) {
    const category = (row.category && row.category.trim()) || "Other";
    let entry = map.get(category);
    if (!entry) {
      entry = {
        category,
        inStockPcs: 0,
        inStockItems: 0,
        outOfStockItems: 0,
        buyValue: 0,
        sellValue: 0,
        soldPcs: 0,
        soldValue: 0,
      };
      map.set(category, entry);
    }

    const qty = Number(row.stock_qty || 0);
    const cost = Number(row.cost_price || 0);
    const sell = Number(row.selling_price || 0);
    const soldPcs = Number(row.stock_out_total || 0);

    if (qty > 0) {
      entry.inStockPcs += qty;
      entry.inStockItems += 1;
      entry.buyValue += qty * cost;
      entry.sellValue += qty * sell;
    } else {
      entry.outOfStockItems += 1;
    }
    entry.soldPcs += soldPcs;
    entry.soldValue += soldPcs * sell;
  }

  // Fixed category order first, then any extras
  const ordered: CategoryStockRow[] = [];
  for (const cat of CLOTHING_CATEGORIES) {
    const row = map.get(cat);
    if (row) ordered.push(row);
  }
  for (const [key, row] of map) {
    if (!(CLOTHING_CATEGORIES as readonly string[]).includes(key)) {
      ordered.push(row);
    }
  }

  const totals = emptyTotals();
  for (const c of ordered) {
    totals.inStockPcs += c.inStockPcs;
    totals.inStockItems += c.inStockItems;
    totals.outOfStockItems += c.outOfStockItems;
    totals.buyValue += c.buyValue;
    totals.sellValue += c.sellValue;
    totals.soldPcs += c.soldPcs;
    totals.soldValue += c.soldValue;
  }

  return { totals, categories: ordered };
}

function parseRpc(payload: unknown): StockOverview | null {
  if (!payload || typeof payload !== "object") return null;
  const data = payload as {
    totals?: Record<string, number>;
    categories?: Record<string, number | string>[];
  };
  const t = data.totals || {};
  const fromRpc = (data.categories || []).map((c) => ({
    category: String(c.category || "Other"),
    inStockPcs: Number(c.in_stock_pcs || 0),
    inStockItems: Number(c.in_stock_items || 0),
    outOfStockItems: Number(c.out_of_stock_items || 0),
    buyValue: Number(c.buy_value || 0),
    sellValue: Number(c.sell_value || 0),
    soldPcs: Number(c.sold_pcs || 0),
    soldValue: Number(c.sold_value || 0),
  }));

  const map = new Map(fromRpc.map((r) => [r.category, r]));
  const categories: CategoryStockRow[] = [];
  for (const cat of CLOTHING_CATEGORIES) {
    categories.push(
      map.get(cat) || {
        category: cat,
        inStockPcs: 0,
        inStockItems: 0,
        outOfStockItems: 0,
        buyValue: 0,
        sellValue: 0,
        soldPcs: 0,
        soldValue: 0,
      },
    );
    map.delete(cat);
  }
  for (const row of map.values()) categories.push(row);

  return {
    totals: {
      inStockPcs: Number(t.in_stock_pcs || 0),
      inStockItems: Number(t.in_stock_items || 0),
      outOfStockItems: Number(t.out_of_stock_items || 0),
      buyValue: Number(t.buy_value || 0),
      sellValue: Number(t.sell_value || 0),
      soldPcs: Number(t.sold_pcs || 0),
      soldValue: Number(t.sold_value || 0),
    },
    categories,
  };
}

export async function loadStockOverview(
  businessId: string,
): Promise<StockOverview> {
  if (DEMO_MODE) {
    const items = getDemoClothingProducts(businessId).filter((p) => p.is_active);
    return summarizeFromRows(
      items.map((p) => ({
        category: p.category,
        stock_qty: Number(p.stock_qty ?? 0),
        cost_price: Number(p.cost_price ?? 0),
        selling_price: Number(p.selling_price ?? 0),
        stock_out_total: Number(p.stock_out_total ?? 0),
      })),
    );
  }

  const supabase = createClient();
  const { data: rpcData, error: rpcError } = await supabase.rpc(
    "clothing_stock_by_category",
    { p_business_id: businessId },
  );

  if (!rpcError && rpcData) {
    const parsed = parseRpc(rpcData);
    if (parsed) return parsed;
  }

  const { data, error } = await supabase
    .from("product_variants")
    .select(
      "stock_qty, cost_price, selling_price, stock_out_total, products(category)",
    )
    .eq("business_id", businessId)
    .eq("is_active", true);

  if (error || !data) {
    return { totals: emptyTotals(), categories: CLOTHING_CATEGORIES.map((c) => ({
      category: c,
      inStockPcs: 0,
      inStockItems: 0,
      outOfStockItems: 0,
      buyValue: 0,
      sellValue: 0,
      soldPcs: 0,
      soldValue: 0,
    })) };
  }

  return summarizeFromRows(
    data.map((row) => {
      const p = Array.isArray(row.products) ? row.products[0] : row.products;
      return {
        category: (p as { category?: string | null } | null)?.category ?? null,
        stock_qty: Number(row.stock_qty || 0),
        cost_price: Number(row.cost_price || 0),
        selling_price: Number(row.selling_price || 0),
        stock_out_total: Number(row.stock_out_total || 0),
      };
    }),
  );
}
