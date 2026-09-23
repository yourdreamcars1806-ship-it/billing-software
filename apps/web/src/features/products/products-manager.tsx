"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Download,
  PackageMinus,
  PackagePlus,
  Pencil,
  Plus,
  ScanBarcode,
  Trash2,
  X,
  Printer,
} from "lucide-react";
import { BarcodeDisplay } from "@/components/barcode/barcode-display";
import { Button } from "@/components/ui/button";
import { LoadingOverlay } from "@/components/ui/spinner";
import {
  DEMO_MODE,
  addDemoClothingProduct,
  deleteDemoClothingProduct,
  deleteDemoClothingProducts,
  getDemoClothingProducts,
  updateDemoClothingProduct,
  updateDemoStock,
} from "@/lib/demo/data";
import {
  downloadBarcodePng,
  downloadBulkBarcodePdf,
} from "@/lib/download-barcode";
import { adjustVariantStock } from "@/lib/stock";
import { createClient } from "@/lib/supabase/client";
import { cn, formatMoney } from "@/lib/utils";
import type { Business, ClothingProductItem } from "@/types";
import { CLOTHING_CATEGORIES } from "./categories";

const emptyForm = {
  name: "",
  brand: "",
  category: "",
  sub_category: "",
  size: "",
  color: "",
  fabric: "",
  cost_price: "",
  selling_price: "",
  tax_rate: "12",
  offer_percent: "0",
  barcode: "",
  stock_qty: "0",
};

const variantSelectCols =
  "id, business_id, product_id, size, color, fabric, cost_price, selling_price, tax_rate, offer_percent, barcode, barcode_format, is_active, stock_qty, stock_out_total";

type SidePanel =
  | { mode: "closed" }
  | { mode: "form"; editItem?: ClothingProductItem }
  | { mode: "barcode"; item: ClothingProductItem };

const fieldClass =
  "mt-1.5 h-10 w-full border border-slate-200 bg-white px-3 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-brand focus:ring-2 focus:ring-brand/15";

function Field({
  label,
  children,
  hint,
}: {
  label: string;
  children: React.ReactNode;
  hint?: string;
}) {
  return (
    <label className="block">
      <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-slate-500">
        {label}
      </span>
      {children}
      {hint ? <p className="mt-1 text-[11px] text-slate-400">{hint}</p> : null}
    </label>
  );
}

export function ProductsManager({ business }: { business: Business }) {
  const [products, setProducts] = useState<ClothingProductItem[]>([]);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);
  const [panel, setPanel] = useState<SidePanel>({ mode: "closed" });
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [bulkBusy, setBulkBusy] = useState(false);

  async function load() {
    setLoading(true);
    setError(null);

    if (DEMO_MODE) {
      setProducts(
        getDemoClothingProducts(business.id).filter((p) => p.is_active),
      );
      setLoading(false);
      return;
    }

    const supabase = createClient();
    const { data, error: qError } = await supabase
      .from("product_variants")
      .select(
        `${variantSelectCols}, products(name, brand, category, sub_category)`,
      )
      .eq("business_id", business.id)
      .eq("is_active", true)
      .order("created_at", { ascending: false });

    if (qError) {
      setError(qError.message);
      setProducts([]);
    } else {
      setProducts(
        (data || []).map((row) => {
          const p = Array.isArray(row.products) ? row.products[0] : row.products;
          return {
            id: row.id,
            business_id: row.business_id,
            product_id: row.product_id,
            name: p?.name || "Product",
            brand: p?.brand ?? null,
            category: p?.category ?? null,
            sub_category: p?.sub_category ?? null,
            size: row.size || "",
            color: row.color || "",
            fabric: row.fabric,
            cost_price: Number(row.cost_price || 0),
            selling_price: Number(row.selling_price),
            tax_rate: Number(row.tax_rate || 0),
            offer_percent: Number(row.offer_percent || 0),
            barcode: row.barcode || "",
            barcode_format: row.barcode_format || "CODE128",
            stock_qty: Number(row.stock_qty || 0),
            stock_out_total: Number(row.stock_out_total || 0),
            is_active: row.is_active !== false,
          };
        }),
      );
    }
    setLoading(false);
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [business.id]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return products;
    return products.filter((p) =>
      [p.name, p.brand, p.category, p.size, p.color, p.barcode]
        .filter(Boolean)
        .some((v) => String(v).toLowerCase().includes(q)),
    );
  }, [products, query]);

  function closePanel() {
    setPanel({ mode: "closed" });
  }

  function openForm() {
    setError(null);
    setSuccess(null);
    setForm(emptyForm);
    setPanel({ mode: "form" });
  }

  function openEdit(item: ClothingProductItem) {
    setError(null);
    setSuccess(null);
    setForm({
      name: item.name,
      brand: item.brand || "",
      category: item.category || "",
      sub_category: item.sub_category || "",
      size: item.size,
      color: item.color,
      fabric: item.fabric || "",
      cost_price: String(item.cost_price ?? 0),
      selling_price: String(item.selling_price),
      tax_rate: String(item.tax_rate),
      offer_percent: String(item.offer_percent ?? 0),
      barcode: item.barcode || "",
      stock_qty: String(item.stock_qty ?? 0),
    });
    setPanel({ mode: "form", editItem: item });
  }

  async function handleStockAdjust(
    item: ClothingProductItem,
    type: "in" | "out",
  ) {
    const label = type === "in" ? "Stock In" : "Stock Out";
    const raw = window.prompt(`${label} — enter quantity:`, "1");
    if (raw === null) return;
    const qty = Number(raw);
    if (!(qty > 0) || !Number.isFinite(qty)) {
      setError("Enter a valid quantity greater than 0");
      return;
    }

    setError(null);
    setSuccess(null);
    setSaving(true);

    if (DEMO_MODE) {
      const updated = updateDemoStock(business.id, item.id, type, qty);
      setSaving(false);
      if (!updated) {
        setError(
          type === "out"
            ? `Only ${item.stock_qty ?? 0} in stock`
            : "Failed to update stock",
        );
        return;
      }
      setSuccess(`${label} · ${qty} · now ${updated.stock_qty}`);
      await load();
      if (typeof window !== "undefined") {
        window.dispatchEvent(new Event("clothing-stock-changed"));
      }
      if (panel.mode === "barcode" && panel.item.id === item.id) {
        setPanel({ mode: "barcode", item: updated });
      }
      return;
    }

    const result = await adjustVariantStock({
      businessId: business.id,
      variantId: item.id,
      type,
      quantity: qty,
      note: type === "in" ? "Stock in" : "Stock out",
    });
    setSaving(false);

    if (!result.success) {
      setError(result.error || "Failed to update stock");
      return;
    }

    setSuccess(`${label} · ${qty} · now ${result.stock_qty}`);
    await load();
    if (typeof window !== "undefined") {
      window.dispatchEvent(new Event("clothing-stock-changed"));
    }
    if (panel.mode === "barcode" && panel.item.id === item.id) {
      setPanel({
        mode: "barcode",
        item: { ...panel.item, stock_qty: result.stock_qty ?? panel.item.stock_qty },
      });
    }
  }

  function openBarcode(item: ClothingProductItem) {
    setPanel({ mode: "barcode", item });
  }

  async function downloadOne(item: ClothingProductItem) {
    setError(null);
    const ok = await downloadBarcodePng(
      item.barcode,
      `${item.barcode}-${item.name}.png`,
      {
        productName: item.name,
        size: item.size,
        color: item.color,
        price: item.selling_price,
      },
    );
    if (!ok) setError(`Could not download barcode ${item.barcode}`);
    else setSuccess(`Sticker downloaded · ${item.barcode}`);
  }

  async function deleteBarcode(item: ClothingProductItem) {
    if (
      !confirm(
        `Delete barcode ${item.barcode} (${item.name} · ${item.color})? It will be removed from the list.`,
      )
    ) {
      return;
    }

    setError(null);
    setSuccess(null);
    setSaving(true);

    if (DEMO_MODE) {
      deleteDemoClothingProduct(business.id, item.id);
      setProducts((prev) => prev.filter((p) => p.id !== item.id));
      setSelectedIds((prev) => {
        const next = new Set(prev);
        next.delete(item.id);
        return next;
      });
      if (panel.mode === "barcode" && panel.item.id === item.id) {
        setPanel({ mode: "closed" });
      }
      setSaving(false);
      setSuccess(`Barcode deleted · ${item.barcode}`);
      return;
    }

    const supabase = createClient();
    const { error: delError } = await supabase
      .from("product_variants")
      .update({ is_active: false })
      .eq("id", item.id)
      .eq("business_id", business.id);

    setSaving(false);

    if (delError) {
      setError(delError.message || "Failed to delete barcode");
      return;
    }

    setSelectedIds((prev) => {
      const next = new Set(prev);
      next.delete(item.id);
      return next;
    });
    if (panel.mode === "barcode" && panel.item.id === item.id) {
      setPanel({ mode: "closed" });
    }
    setSuccess(`Barcode deleted · ${item.barcode}`);
    await load();
  }

  async function bulkDeleteSelected() {
    const items = filtered.filter((p) => selectedIds.has(p.id));
    if (!items.length) {
      setError("Select at least one barcode to delete");
      return;
    }
    if (
      !confirm(
        `Delete ${items.length} barcode${items.length === 1 ? "" : "s"}? They will be removed from the list.`,
      )
    ) {
      return;
    }

    setError(null);
    setSuccess(null);
    setBulkBusy(true);

    if (DEMO_MODE) {
      deleteDemoClothingProducts(
        business.id,
        items.map((i) => i.id),
      );
      const ids = new Set(items.map((i) => i.id));
      setProducts((prev) => prev.filter((p) => !ids.has(p.id)));
      setSelectedIds(new Set());
      if (panel.mode === "barcode" && ids.has(panel.item.id)) {
        setPanel({ mode: "closed" });
      }
      setBulkBusy(false);
      setSuccess(`Deleted ${items.length} barcode${items.length === 1 ? "" : "s"}`);
      return;
    }

    const supabase = createClient();
    const { error: delError } = await supabase
      .from("product_variants")
      .update({ is_active: false })
      .eq("business_id", business.id)
      .in(
        "id",
        items.map((i) => i.id),
      );

    setBulkBusy(false);

    if (delError) {
      setError(delError.message || "Failed to delete barcodes");
      return;
    }

    setSelectedIds(new Set());
    if (
      panel.mode === "barcode" &&
      items.some((i) => i.id === panel.item.id)
    ) {
      setPanel({ mode: "closed" });
    }
    setSuccess(`Deleted ${items.length} barcode${items.length === 1 ? "" : "s"}`);
    await load();
  }

  function toggleSelect(id: string) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleSelectAll() {
    if (selectedIds.size === filtered.length) {
      setSelectedIds(new Set());
      return;
    }
    setSelectedIds(new Set(filtered.map((p) => p.id)));
  }

  async function bulkPrint(items: ClothingProductItem[]) {
    if (!items.length) {
      setError("Select at least one product for bulk barcodes");
      return;
    }
    setError(null);
    setBulkBusy(true);
    try {
      const ok = await downloadBulkBarcodePdf(
        items.map((item) => ({
          barcode: item.barcode,
          productName: item.name,
          size: item.size,
          color: item.color,
          price: item.selling_price,
        })),
        `drape-barcodes-${items.length}.pdf`,
      );
      if (!ok) setError("Bulk barcode PDF failed");
      else
        setSuccess(
          `Bulk sheet ready · ${items.length} labels (A4 · 60 per page · 38×18 mm)`,
        );
    } catch {
      setError("Bulk barcode PDF failed");
    } finally {
      setBulkBusy(false);
    }
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    const name = form.name.trim();
    const size = form.size.trim();
    const color = form.color.trim();
    const category = form.category.trim();
    const costPrice = Math.max(0, Number(form.cost_price) || 0);
    const price = Number(form.selling_price);
    const tax = Number(form.tax_rate);
    const offer = Number(form.offer_percent);
    const stockQty = Math.max(0, Number(form.stock_qty) || 0);
    const barcodeTrim = form.barcode.trim();
    const editItem = panel.mode === "form" ? panel.editItem : undefined;

    if (!name || !size || !color || !(price > 0)) {
      setError("Name, size, color, and sell price are required");
      return;
    }

    if (Number.isNaN(costPrice) || costPrice < 0) {
      setError("Cost price must be 0 or more");
      return;
    }

    if (
      !category ||
      !(CLOTHING_CATEGORIES as readonly string[]).includes(category)
    ) {
      setError("Select a valid category");
      return;
    }

    if (Number.isNaN(offer) || offer < 0 || offer > 100) {
      setError("Offer % must be between 0 and 100");
      return;
    }

    if (editItem && !barcodeTrim) {
      setError("Barcode is required when editing");
      return;
    }

    setSaving(true);

    const productFields = {
      name,
      brand: form.brand.trim() || null,
      category,
      sub_category: form.sub_category.trim() || null,
    };

    if (DEMO_MODE) {
      if (editItem) {
        const item = updateDemoClothingProduct(business.id, editItem.id, {
          ...productFields,
          brand: form.brand,
          category,
          sub_category: form.sub_category,
          size,
          color,
          fabric: form.fabric,
          cost_price: costPrice,
          selling_price: price,
          tax_rate: tax,
          offer_percent: offer,
          barcode: barcodeTrim,
        });
        setSaving(false);
        if (!item) {
          setError("Failed to update product");
          return;
        }
        setSuccess(`Product updated · ${item.barcode}`);
        setForm(emptyForm);
        await load();
        setPanel({ mode: "barcode", item });
        return;
      }

      const item = addDemoClothingProduct(business.id, {
        name,
        brand: form.brand,
        category,
        sub_category: form.sub_category,
        size,
        color,
        fabric: form.fabric,
        cost_price: costPrice,
        selling_price: price,
        tax_rate: tax,
        offer_percent: offer,
        stock_qty: stockQty,
        ...(barcodeTrim ? { barcode: barcodeTrim } : {}),
      });
      setSuccess(`Barcode generated: ${item.barcode}`);
      setForm(emptyForm);
      await load();
      setSaving(false);
      setPanel({ mode: "barcode", item });
      return;
    }

    const supabase = createClient();

    if (editItem) {
      let productId = editItem.product_id;
      if (!productId) {
        const { data: existing } = await supabase
          .from("product_variants")
          .select("product_id")
          .eq("id", editItem.id)
          .eq("business_id", business.id)
          .single();
        productId = existing?.product_id;
      }

      if (productId) {
        const { error: pErr } = await supabase
          .from("products")
          .update(productFields)
          .eq("id", productId)
          .eq("business_id", business.id);
        if (pErr) {
          setSaving(false);
          setError(pErr.message || "Failed to update product");
          return;
        }
      }

      const { data: variant, error: vErr } = await supabase
        .from("product_variants")
        .update({
          size,
          color,
          fabric: form.fabric.trim() || null,
          cost_price: costPrice,
          selling_price: price,
          tax_rate: tax,
          offer_percent: offer,
          barcode: barcodeTrim,
        })
        .eq("id", editItem.id)
        .eq("business_id", business.id)
        .select(variantSelectCols)
        .single();

      setSaving(false);

      if (vErr || !variant) {
        setError(vErr?.message || "Failed to update variant");
        return;
      }

      const item: ClothingProductItem = {
        id: variant.id,
        business_id: variant.business_id,
        product_id: variant.product_id,
        name,
        brand: productFields.brand,
        category: productFields.category,
        sub_category: productFields.sub_category,
        size: variant.size || size,
        color: variant.color || color,
        fabric: variant.fabric,
        cost_price: Number(variant.cost_price || costPrice),
        selling_price: Number(variant.selling_price),
        tax_rate: Number(variant.tax_rate || tax),
        offer_percent: Number(variant.offer_percent || offer),
        barcode: variant.barcode || barcodeTrim,
        barcode_format: variant.barcode_format || "CODE128",
        stock_qty: Number(variant.stock_qty || 0),
        is_active: true,
      };

      setSuccess(`Product updated · ${item.barcode}`);
      setForm(emptyForm);
      await load();
      setPanel({ mode: "barcode", item });
      return;
    }

    const { data: product, error: pErr } = await supabase
      .from("products")
      .insert({
        business_id: business.id,
        ...productFields,
        is_active: true,
      })
      .select("id")
      .single();

    if (pErr || !product) {
      setSaving(false);
      setError(pErr?.message || "Failed to create product");
      return;
    }

    const { data: variant, error: vErr } = await supabase
      .from("product_variants")
      .insert({
        business_id: business.id,
        product_id: product.id,
        size,
        color,
        fabric: form.fabric.trim() || null,
        cost_price: costPrice,
        selling_price: price,
        tax_rate: tax,
        offer_percent: offer,
        stock_qty: stockQty,
        stock_in_total: stockQty > 0 ? stockQty : 0,
        stock_out_total: 0,
        is_active: true,
        ...(barcodeTrim ? { barcode: barcodeTrim } : {}),
      })
      .select(variantSelectCols)
      .single();

    setSaving(false);

    if (vErr || !variant) {
      setError(vErr?.message || "Failed to create variant");
      return;
    }

    if (stockQty > 0) {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      await supabase.from("stock_movements").insert({
        business_id: business.id,
        product_variant_id: variant.id,
        movement_type: "in",
        quantity: stockQty,
        note: "Opening stock",
        created_by: user?.id || null,
      });
    }

    const item: ClothingProductItem = {
      id: variant.id,
      business_id: variant.business_id,
      product_id: variant.product_id,
      name,
      brand: productFields.brand,
      category: productFields.category,
      sub_category: productFields.sub_category,
      size: variant.size || size,
      color: variant.color || color,
      fabric: variant.fabric,
      cost_price: Number(variant.cost_price || costPrice),
      selling_price: Number(variant.selling_price),
      tax_rate: Number(variant.tax_rate || tax),
      offer_percent: Number(variant.offer_percent || offer),
      barcode: variant.barcode || "",
      barcode_format: variant.barcode_format || "CODE128",
      stock_qty: Number(variant.stock_qty || stockQty),
      is_active: true,
    };

    setSuccess(`Barcode generated: ${item.barcode}`);
    setForm(emptyForm);
    await load();
    if (typeof window !== "undefined") {
      window.dispatchEvent(new Event("clothing-stock-changed"));
    }
    setPanel({ mode: "barcode", item });
  }

  const panelOpen = panel.mode !== "closed";

  return (
    <div className="space-y-5">
      <LoadingOverlay
        show={loading || saving || bulkBusy}
        label={
          bulkBusy
            ? "Working on barcodes…"
            : saving
              ? "Please wait…"
              : "Loading products…"
        }
      />
      <div className="flex flex-col gap-3 border-b border-slate-200 pb-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-xl font-semibold tracking-tight text-slate-900">
            Products & Barcode
          </h1>
          <p className="mt-0.5 text-sm text-slate-500">
            Compact barcode labels · 38×18 mm
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button
            type="button"
            variant="outline"
            disabled={!filtered.length || bulkBusy}
            onClick={() => bulkPrint(filtered)}
          >
            <Printer className="h-4 w-4" />
            Print all ({filtered.length})
          </Button>
          <Button
            type="button"
            variant="outline"
            disabled={!selectedIds.size || bulkBusy}
            onClick={() =>
              bulkPrint(filtered.filter((p) => selectedIds.has(p.id)))
            }
          >
            <Printer className="h-4 w-4" />
            Print selected ({selectedIds.size})
          </Button>
          <Button
            type="button"
            variant="outline"
            className="border-red-200 text-red-700 hover:bg-red-50"
            disabled={!selectedIds.size || bulkBusy}
            onClick={() => void bulkDeleteSelected()}
          >
            <Trash2 className="h-4 w-4" />
            Delete selected ({selectedIds.size})
          </Button>
          <Button type="button" onClick={openForm}>
            <Plus className="h-4 w-4" />
            Generate barcode
          </Button>
        </div>
      </div>

      {error && (
        <div className="border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </div>
      )}
      {success && (
        <div className="border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
          {success}
        </div>
      )}

      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <input
          type="search"
          placeholder="Search products or barcode…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="h-9 w-full max-w-sm border border-slate-200 bg-white px-3 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/15"
        />
        <p className="text-xs tabular-nums text-slate-500">
          {filtered.length} rows · Code 128
        </p>
      </div>

      {loading ? (
        <p className="py-10 text-sm text-slate-500">Loading…</p>
      ) : filtered.length === 0 ? (
        <div className="border border-dashed border-slate-300 py-16 text-center">
          <ScanBarcode className="mx-auto h-7 w-7 text-slate-300" />
          <p className="mt-3 text-sm font-medium text-slate-700">No products</p>
          <p className="mt-1 text-sm text-slate-500">
            Click Generate barcode to add the first item.
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto border border-slate-200 bg-white">
          <table className="min-w-full border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50/80">
                <th className="whitespace-nowrap px-3 py-2.5">
                  <input
                    type="checkbox"
                    className="h-3.5 w-3.5 rounded border-slate-300"
                    checked={
                      filtered.length > 0 &&
                      selectedIds.size === filtered.length
                    }
                    onChange={toggleSelectAll}
                    aria-label="Select all"
                  />
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  #
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Product
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Brand
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Size
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Color
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Cost
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Sell
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Offer
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Stock
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Barcode
                </th>
                <th className="whitespace-nowrap px-3 py-2.5 text-right text-[11px] font-semibold uppercase tracking-wider text-slate-500">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((item, index) => {
                const selected =
                  panel.mode === "barcode" && panel.item.id === item.id;
                const checked = selectedIds.has(item.id);
                return (
                  <tr
                    key={item.id}
                    className={cn(
                      "border-b border-slate-100 last:border-0 hover:bg-slate-50/70",
                      selected && "bg-brand-soft hover:bg-brand-soft",
                      checked && !selected && "bg-brand-soft/60",
                    )}
                  >
                    <td className="px-3 py-2.5">
                      <input
                        type="checkbox"
                        className="h-3.5 w-3.5 rounded border-slate-300"
                        checked={checked}
                        onChange={() => toggleSelect(item.id)}
                        aria-label={`Select ${item.name}`}
                      />
                    </td>
                    <td className="px-3 py-2.5 tabular-nums text-slate-400">
                      {index + 1}
                    </td>
                    <td className="px-3 py-2.5 font-medium text-slate-900">
                      {item.name}
                      {item.category ? (
                        <span className="mt-0.5 block text-xs font-normal text-slate-500">
                          {item.category}
                        </span>
                      ) : null}
                    </td>
                    <td className="px-3 py-2.5 text-slate-600">
                      {item.brand || "-"}
                    </td>
                    <td className="px-3 py-2.5 text-slate-700">{item.size}</td>
                    <td className="px-3 py-2.5 text-slate-700">{item.color}</td>
                    <td className="px-3 py-2.5 tabular-nums text-slate-600">
                      {formatMoney(item.cost_price ?? 0)}
                    </td>
                    <td className="px-3 py-2.5 tabular-nums font-medium text-slate-900">
                      {formatMoney(item.selling_price)}
                    </td>
                    <td className="px-3 py-2.5 tabular-nums text-slate-700">
                      {item.offer_percent > 0 ? `${item.offer_percent}%` : "-"}
                    </td>
                    <td
                      className={cn(
                        "px-3 py-2.5 tabular-nums font-medium",
                        (item.stock_qty ?? 0) <= 0
                          ? "text-red-600"
                          : "text-slate-900",
                      )}
                    >
                      {item.stock_qty ?? 0}
                    </td>
                    <td className="px-3 py-2.5">
                      <button
                        type="button"
                        onClick={() => openBarcode(item)}
                        className="font-mono text-xs font-semibold text-brand-ink underline decoration-brand-border underline-offset-2 hover:text-brand-dark"
                      >
                        {item.barcode}
                      </button>
                    </td>
                    <td className="px-3 py-2.5 text-right">
                      <div className="inline-flex items-center justify-end gap-1.5">
                        <button
                          type="button"
                          onClick={() => void handleStockAdjust(item, "in")}
                          className="inline-flex items-center gap-1 border border-emerald-200 px-2 py-1 text-xs font-medium text-emerald-700 hover:bg-emerald-50"
                          title={`Stock in · ${item.name}`}
                        >
                          <PackagePlus className="h-3.5 w-3.5" />
                          In
                        </button>
                        <button
                          type="button"
                          onClick={() => void handleStockAdjust(item, "out")}
                          className="inline-flex items-center gap-1 border border-amber-200 px-2 py-1 text-xs font-medium text-amber-800 hover:bg-amber-50"
                          title={`Stock out · ${item.name}`}
                        >
                          <PackageMinus className="h-3.5 w-3.5" />
                          Out
                        </button>
                        <button
                          type="button"
                          onClick={() => openEdit(item)}
                          className="inline-flex items-center gap-1.5 border border-slate-200 px-2.5 py-1 text-xs font-medium text-slate-700 hover:border-slate-300 hover:bg-slate-50"
                          title={`Edit ${item.name}`}
                        >
                          <Pencil className="h-3.5 w-3.5" />
                          Edit
                        </button>
                        <button
                          type="button"
                          onClick={() => downloadOne(item)}
                          className="inline-flex items-center gap-1.5 border border-slate-200 px-2.5 py-1 text-xs font-medium text-slate-700 hover:border-slate-300 hover:bg-slate-50"
                          title={`Download ${item.barcode}`}
                        >
                          <Download className="h-3.5 w-3.5" />
                          PNG
                        </button>
                        <button
                          type="button"
                          onClick={() => void deleteBarcode(item)}
                          className="inline-flex items-center gap-1.5 border border-red-200 px-2.5 py-1 text-xs font-medium text-red-700 hover:bg-red-50"
                          title={`Delete ${item.barcode}`}
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {panelOpen && (
        <div className="fixed inset-0 z-50 flex justify-end">
          <button
            type="button"
            className="absolute inset-0 bg-slate-900/35"
            aria-label="Close panel"
            onClick={closePanel}
          />
          <aside className="relative z-10 flex h-full w-full max-w-[420px] flex-col bg-white shadow-2xl">
            <div className="flex items-start justify-between border-b border-slate-200 px-6 py-5">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-brand-ink">
                  {panel.mode === "form"
                    ? panel.editItem
                      ? "Edit"
                      : "Generate"
                    : "Barcode detail"}
                </p>
                <h2 className="mt-1 text-lg font-semibold text-slate-900">
                  {panel.mode === "form"
                    ? panel.editItem
                      ? "Edit clothing product"
                      : "New clothing barcode"
                    : panel.item.barcode}
                </h2>
                {panel.mode === "form" && (
                  <p className="mt-1 text-sm text-slate-500">
                    {panel.editItem
                      ? "Update details and save changes."
                      : "Fill details - Code 128 barcode auto-creates on save."}
                  </p>
                )}
              </div>
              <button
                type="button"
                onClick={closePanel}
                className="rounded-md p-2 text-slate-400 hover:bg-slate-100 hover:text-slate-800"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto px-6 py-6">
              {panel.mode === "form" && (
                <form onSubmit={submit} className="space-y-5">
                  <section className="space-y-4">
                    <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate-400">
                      Product
                    </p>
                    <Field label="Product name">
                      <input
                        className={fieldClass}
                        value={form.name}
                        onChange={(e) =>
                          setForm((f) => ({ ...f, name: e.target.value }))
                        }
                        placeholder="Oxford Cotton Shirt"
                        required
                      />
                    </Field>
                    <div className="grid grid-cols-2 gap-3">
                      <Field label="Brand">
                        <input
                          className={fieldClass}
                          value={form.brand}
                          onChange={(e) =>
                            setForm((f) => ({ ...f, brand: e.target.value }))
                          }
                          placeholder="Drape"
                        />
                      </Field>
                      <Field label="Category">
                        <select
                          className={fieldClass}
                          value={form.category}
                          required
                          onChange={(e) =>
                            setForm((f) => ({ ...f, category: e.target.value }))
                          }
                        >
                          <option value="">Select category</option>
                          {CLOTHING_CATEGORIES.map((cat) => (
                            <option key={cat} value={cat}>
                              {cat}
                            </option>
                          ))}
                        </select>
                      </Field>
                    </div>
                    <Field
                      label="Sub category"
                      hint="Optional — e.g. Formal, Casual"
                    >
                      <input
                        className={fieldClass}
                        value={form.sub_category}
                        onChange={(e) =>
                          setForm((f) => ({
                            ...f,
                            sub_category: e.target.value,
                          }))
                        }
                        placeholder="Optional"
                      />
                    </Field>
                  </section>

                  <section className="space-y-4 border-t border-slate-100 pt-5">
                    <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate-400">
                      Variant
                    </p>
                    <div className="grid grid-cols-2 gap-3">
                      <Field label="Size">
                        <input
                          className={fieldClass}
                          value={form.size}
                          onChange={(e) =>
                            setForm((f) => ({ ...f, size: e.target.value }))
                          }
                          placeholder="M"
                          required
                        />
                      </Field>
                      <Field label="Color">
                        <input
                          className={fieldClass}
                          value={form.color}
                          onChange={(e) =>
                            setForm((f) => ({ ...f, color: e.target.value }))
                          }
                          placeholder="Black"
                          required
                        />
                      </Field>
                    </div>
                    <Field label="Fabric">
                      <input
                        className={fieldClass}
                        value={form.fabric}
                        onChange={(e) =>
                          setForm((f) => ({ ...f, fabric: e.target.value }))
                        }
                        placeholder="Cotton"
                      />
                    </Field>
                  </section>

                  <section className="space-y-4 border-t border-slate-100 pt-5">
                    <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate-400">
                      Pricing
                    </p>
                    <div className="grid grid-cols-2 gap-3">
                      <Field
                        label="Cost price (₹)"
                        hint="Purchase / buy price"
                      >
                        <input
                          className={fieldClass}
                          type="number"
                          min={0}
                          step="0.01"
                          value={form.cost_price}
                          onChange={(e) =>
                            setForm((f) => ({
                              ...f,
                              cost_price: e.target.value,
                            }))
                          }
                          placeholder="800"
                        />
                      </Field>
                      <Field label="Sell price (₹)">
                        <input
                          className={fieldClass}
                          type="number"
                          min={0}
                          step="0.01"
                          value={form.selling_price}
                          onChange={(e) =>
                            setForm((f) => ({
                              ...f,
                              selling_price: e.target.value,
                            }))
                          }
                          placeholder="1499"
                          required
                        />
                      </Field>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <Field label="Tax %">
                        <input
                          className={fieldClass}
                          type="number"
                          min={0}
                          step="0.01"
                          value={form.tax_rate}
                          onChange={(e) =>
                            setForm((f) => ({ ...f, tax_rate: e.target.value }))
                          }
                        />
                      </Field>
                      <Field
                        label="Offer %"
                        hint="Offer % auto-cuts price when barcode scanned on Billing"
                      >
                        <input
                          className={fieldClass}
                          type="number"
                          min={0}
                          max={100}
                          step="0.01"
                          value={form.offer_percent}
                          onChange={(e) =>
                            setForm((f) => ({
                              ...f,
                              offer_percent: e.target.value,
                            }))
                          }
                          placeholder="0"
                        />
                      </Field>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <Field
                        label="Opening / Stock qty"
                        hint={
                          panel.editItem
                            ? "Current stock — use Stock In/Out to change"
                            : "Initial stock on create"
                        }
                      >
                        <input
                          className={fieldClass}
                          type="number"
                          min={0}
                          step="1"
                          value={form.stock_qty}
                          onChange={(e) =>
                            setForm((f) => ({
                              ...f,
                              stock_qty: e.target.value,
                            }))
                          }
                          placeholder="0"
                          readOnly={Boolean(panel.editItem)}
                          disabled={Boolean(panel.editItem)}
                        />
                      </Field>
                    </div>
                    <Field
                      label="Barcode"
                      hint={
                        panel.editItem
                          ? "Required — editable"
                          : "Optional — auto-generated if empty"
                      }
                    >
                      <input
                        className={fieldClass}
                        value={form.barcode}
                        onChange={(e) =>
                          setForm((f) => ({ ...f, barcode: e.target.value }))
                        }
                        placeholder={
                          panel.editItem ? "Barcode" : "Leave blank to auto"
                        }
                        required={Boolean(panel.editItem)}
                      />
                    </Field>
                    <p className="rounded-sm bg-brand-soft px-3 py-2 text-xs text-brand-dark">
                      Barcode format:{" "}
                      <span className="font-mono font-semibold">
                        DD + YYMM + 6 digits
                      </span>{" "}
                      · Code 128
                    </p>
                  </section>

                  <div className="sticky bottom-0 -mx-6 border-t border-slate-200 bg-white px-6 pt-4">
                    <Button
                      type="submit"
                      className="w-full"
                      size="lg"
                      loading={saving}
                    >
                      {panel.editItem ? "Save changes" : "Generate barcode"}
                    </Button>
                  </div>
                </form>
              )}

              {panel.mode === "barcode" && (
                <div className="space-y-6">
                  <dl className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
                    <div>
                      <dt className="text-xs text-slate-500">Product</dt>
                      <dd className="font-medium text-slate-900">
                        {panel.item.name}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-xs text-slate-500">Brand</dt>
                      <dd className="text-slate-800">
                        {panel.item.brand || "-"}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-xs text-slate-500">Size</dt>
                      <dd className="text-slate-800">{panel.item.size}</dd>
                    </div>
                    <div>
                      <dt className="text-xs text-slate-500">Color</dt>
                      <dd className="text-slate-800">{panel.item.color}</dd>
                    </div>
                    <div>
                      <dt className="text-xs text-slate-500">Cost price</dt>
                      <dd className="tabular-nums text-slate-800">
                        {formatMoney(panel.item.cost_price ?? 0)}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-xs text-slate-500">Sell price</dt>
                      <dd className="font-semibold tabular-nums text-slate-900">
                        {formatMoney(panel.item.selling_price)}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-xs text-slate-500">Offer</dt>
                      <dd className="tabular-nums text-slate-800">
                        {panel.item.offer_percent > 0
                          ? `${panel.item.offer_percent}%`
                          : "-"}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-xs text-slate-500">Tax</dt>
                      <dd className="text-slate-800">{panel.item.tax_rate}%</dd>
                    </div>
                    <div>
                      <dt className="text-xs text-slate-500">Stock qty</dt>
                      <dd
                        className={cn(
                          "font-semibold tabular-nums",
                          (panel.item.stock_qty ?? 0) <= 0
                            ? "text-red-600"
                            : "text-slate-900",
                        )}
                      >
                        {panel.item.stock_qty ?? 0}
                      </dd>
                    </div>
                  </dl>

                  <div className="flex gap-2">
                    <Button
                      type="button"
                      variant="outline"
                      className="flex-1 border-emerald-200 text-emerald-700 hover:bg-emerald-50"
                      onClick={() => void handleStockAdjust(panel.item, "in")}
                    >
                      <PackagePlus className="h-4 w-4" />
                      Stock In
                    </Button>
                    <Button
                      type="button"
                      variant="outline"
                      className="flex-1 border-amber-200 text-amber-800 hover:bg-amber-50"
                      onClick={() => void handleStockAdjust(panel.item, "out")}
                    >
                      <PackageMinus className="h-4 w-4" />
                      Stock Out
                    </Button>
                  </div>

                  <div className="border border-brand-border bg-brand-soft/40 py-6 text-center">
                    <div className="flex justify-center">
                      <BarcodeDisplay
                        value={panel.item.barcode}
                        productName={panel.item.name}
                        size={panel.item.size}
                        color={panel.item.color}
                        price={panel.item.selling_price}
                      />
                    </div>
                    <p className="mt-4 text-xs text-slate-500">
                      Print-ready label · 38 × 18 mm
                    </p>
                  </div>

                  <div className="flex flex-col gap-2">
                    <Button
                      type="button"
                      className="w-full"
                      size="lg"
                      onClick={() => downloadOne(panel.item)}
                    >
                      <Download className="h-4 w-4" />
                      Download barcode PNG
                    </Button>
                    <Button
                      type="button"
                      variant="outline"
                      className="w-full"
                      size="lg"
                      onClick={() => openEdit(panel.item)}
                    >
                      <Pencil className="h-4 w-4" />
                      Edit product
                    </Button>
                    <Button
                      type="button"
                      variant="outline"
                      className="w-full border-red-200 text-red-700 hover:bg-red-50"
                      size="lg"
                      onClick={() => void deleteBarcode(panel.item)}
                    >
                      <Trash2 className="h-4 w-4" />
                      Delete barcode
                    </Button>
                  </div>
                </div>
              )}
            </div>
          </aside>
        </div>
      )}
    </div>
  );
}
