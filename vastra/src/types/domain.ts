export type WardrobeCategory =
  | "tops"
  | "trousers"
  | "skirts"
  | "dresses"
  | "outerwear"
  | "shoes"
  | "bags"
  | "accessories";

export type Occasion =
  | "work"
  | "casual"
  | "date"
  | "formal"
  | "sport"
  | "travel"
  | "custom";

export type MatchStatus = "matched" | "similar" | "missing";

export type TryOnStatus =
  | "queued"
  | "uploading"
  | "processing"
  | "success"
  | "error";

export type GarmentCategory =
  | "full_body"
  | "upper_body"
  | "lower_body"
  | "outer"
  | "shoes"
  | "auto";

export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  createdAt: number;
  updatedAt: number;
  onboardingComplete: boolean;
  consentAiProcessing: boolean;
  tryOnPhotoPath: string | null;
  tryOnPhotoUrl: string | null;
  preferredCity: string | null;
  styleNotes: string | null;
}

export interface WardrobeItem {
  id: string;
  userId: string;
  name: string;
  category: WardrobeCategory;
  colour: string;
  pattern: string | null;
  material: string | null;
  brand: string | null;
  size: string | null;
  seasonTags: string[];
  occasionTags: Occasion[];
  notes: string | null;
  imagePath: string;
  imageUrl: string;
  cutoutPath: string | null;
  cutoutUrl: string | null;
  youcamFileId: string | null;
  createdAt: number;
  updatedAt: number;
}

export interface InspirationComponent {
  id: string;
  category: WardrobeCategory | "unknown";
  colour: string;
  pattern: string | null;
  styleDescription: string;
  matchStatus: MatchStatus;
  matchedWardrobeItemId: string | null;
  confidence: number;
}

export interface Inspiration {
  id: string;
  userId: string;
  imagePath: string;
  imageUrl: string;
  sourceUrl: string | null;
  components: InspirationComponent[];
  analysisStatus: "pending" | "ready" | "error";
  analysisError: string | null;
  createdAt: number;
}

export interface OutfitItem {
  wardrobeItemId: string | null;
  componentCategory: WardrobeCategory | "unknown";
  role: "matched" | "similar" | "missing" | "manual";
}

export interface Outfit {
  id: string;
  userId: string;
  name: string;
  occasion: Occasion | null;
  inspirationId: string | null;
  items: OutfitItem[];
  missingCategories: WardrobeCategory[];
  createdAt: number;
  updatedAt: number;
}

export interface Product {
  id: string;
  name: string;
  category: WardrobeCategory;
  garmentCategory: GarmentCategory;
  retailer: string;
  imageUrl: string;
  productUrl: string;
  priceGbp: number | null;
  material: string | null;
  sizes: string[];
  dataSource: "curated" | "demo";
  priceCheckedAt: number | null;
  colour: string;
  styleTags: string[];
}

export interface TryOnJob {
  id: string;
  userId: string;
  productId: string | null;
  wardrobeItemId: string | null;
  outfitId: string | null;
  garmentCategory: GarmentCategory;
  personPhotoPath: string;
  garmentImageUrl: string;
  status: TryOnStatus;
  providerTaskId: string | null;
  resultPath: string | null;
  resultUrl: string | null;
  errorCode: string | null;
  errorMessage: string | null;
  unitsSpent: number;
  createdAt: number;
  updatedAt: number;
  completedAt: number | null;
}

export interface SavedLook {
  id: string;
  userId: string;
  name: string;
  outfitId: string | null;
  tryOnJobId: string | null;
  productId: string | null;
  resultUrl: string | null;
  createdAt: number;
}

export interface WeatherSnapshot {
  location: string;
  temperatureC: number;
  feelsLikeC: number;
  humidity: number;
  precipMm: number;
  windKph: number;
  description: string;
  isDay: boolean;
  fetchedAt: number;
}

export interface DailySuggestion {
  id: string;
  title: string;
  reason: string;
  occasion: Occasion;
  wardrobeItemIds: string[];
  weatherAware: boolean;
}

export const WARDROBE_CATEGORIES: { value: WardrobeCategory; label: string }[] =
  [
    { value: "tops", label: "Tops" },
    { value: "trousers", label: "Trousers & jeans" },
    { value: "skirts", label: "Skirts" },
    { value: "dresses", label: "Dresses" },
    { value: "outerwear", label: "Outerwear" },
    { value: "shoes", label: "Shoes" },
    { value: "bags", label: "Bags" },
    { value: "accessories", label: "Accessories" },
  ];

export const OCCASIONS: { value: Occasion; label: string }[] = [
  { value: "work", label: "Work" },
  { value: "casual", label: "Casual" },
  { value: "date", label: "Date" },
  { value: "formal", label: "Formal" },
  { value: "sport", label: "Sport" },
  { value: "travel", label: "Travel" },
  { value: "custom", label: "Custom" },
];

export const GARMENT_CATEGORIES: { value: GarmentCategory; label: string }[] = [
  { value: "full_body", label: "Full body" },
  { value: "upper_body", label: "Upper body" },
  { value: "lower_body", label: "Lower body" },
  { value: "outer", label: "Outerwear" },
  { value: "shoes", label: "Shoes" },
  { value: "auto", label: "Auto detect" },
];
