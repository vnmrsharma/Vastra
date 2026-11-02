import sharp from "sharp";

/** Background-free images trimmed to the subject and re-encoded as small WebP files for the app. */
export async function optimiseCutout(buffer: Buffer): Promise<{ full: Buffer; thumb: Buffer }> {
  let trimmed: Buffer;
  try {
    trimmed = await sharp(buffer).trim({ threshold: 8 }).png().toBuffer();
  } catch {
    trimmed = buffer;
  }
  const encode = (side: number, quality: number) =>
    sharp(trimmed)
      .resize({ width: side, height: side, fit: "inside", withoutEnlargement: true })
      .webp({ quality, alphaQuality: 90, effort: 4 })
      .toBuffer();
  const [full, thumb] = await Promise.all([encode(1100, 86), encode(360, 80)]);
  return { full, thumb };
}
