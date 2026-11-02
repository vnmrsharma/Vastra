import type { ButtonHTMLAttributes, ReactNode } from "react";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "soft";

const styles: Record<Variant, string> = {
  primary:
    "bg-burgundy text-soft-white hover:bg-burgundy-soft shadow-[0_8px_20px_rgba(139,61,74,0.22)] disabled:opacity-50",
  secondary:
    "bg-soft-white text-charcoal border border-border hover:bg-ivory-deep disabled:opacity-50",
  soft: "bg-blush/70 text-burgundy hover:bg-blush disabled:opacity-50",
  ghost: "bg-transparent text-chocolate hover:bg-ivory-deep disabled:opacity-50",
  danger: "bg-danger text-soft-white hover:opacity-90 disabled:opacity-50",
};

export function Button({
  children,
  variant = "primary",
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  children: ReactNode;
  variant?: Variant;
}) {
  return (
    <button
      className={`inline-flex items-center justify-center gap-2 rounded-full px-5 py-2.5 text-sm font-medium tracking-wide transition active:scale-[0.98] ${styles[variant]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}
