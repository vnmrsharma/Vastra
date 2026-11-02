import type { InputHTMLAttributes } from "react";

export function Input({
  className = "",
  ...props
}: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={`w-full rounded-xl border border-border bg-soft-white px-3.5 py-2.5 text-sm text-charcoal outline-none transition placeholder:text-muted focus:border-chocolate focus:ring-2 focus:ring-blush/60 ${className}`}
      {...props}
    />
  );
}
