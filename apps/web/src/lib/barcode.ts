/** Code 128–compatible clothing barcode helpers (Drape & Dream only) */

export const BARCODE_FORMAT = "CODE128" as const;
export const BARCODE_PREFIX = "DD";

/** Format: DD + YYMM + 6-digit sequence → e.g. DD2603000042 */
export function generateClothingBarcode(sequence: number, date = new Date()): string {
  const yy = String(date.getFullYear()).slice(-2);
  const mm = String(date.getMonth() + 1).padStart(2, "0");
  const seq = String(Math.max(1, sequence)).padStart(6, "0");
  return `${BARCODE_PREFIX}${yy}${mm}${seq}`;
}

export function isValidClothingBarcode(code: string): boolean {
  return /^DD\d{10}$/.test(code.trim().toUpperCase());
}

export function nextSequenceFromBarcodes(barcodes: string[]): number {
  let max = 0;
  for (const raw of barcodes) {
    const code = raw.trim().toUpperCase();
    if (!isValidClothingBarcode(code)) continue;
    const n = Number(code.slice(-6));
    if (!Number.isNaN(n) && n > max) max = n;
  }
  return max + 1;
}
