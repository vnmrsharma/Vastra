import type { SelectHTMLAttributes } from "react";

export function Select({
  className = "",
  children,
  ...props
}: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={`w-full rounded-xl border border-border bg-soft-white px-3.5 py-2.5 text-sm text-charcoal outline-none transition focus:border-chocolate focus:ring-2 focus:ring-blush/60 ${className}`}
      {...props}
    >
      {children}
    </select>
  );
}
