"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import { useAuth } from "@/lib/auth/AuthProvider";
import { Button } from "@/components/ui/Button";

const nav = [
  { href: "/app", label: "Home" },
  { href: "/app/closet", label: "Closet" },
  { href: "/app/inspiration", label: "Inspiration" },
  { href: "/app/dress-me", label: "Dress me" },
  { href: "/app/try-on", label: "Try-On" },
  { href: "/app/looks", label: "Looks" },
];

export function AppShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const { profile, signOut } = useAuth();

  return (
    <div className="min-h-screen pb-24 md:pb-0">
      <header className="sticky top-0 z-40 border-b border-border/70 bg-soft-white/85 backdrop-blur-xl">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3 md:px-6">
          <Link
            href="/app"
            className="font-display text-2xl tracking-tight text-charcoal"
          >
            Vastra
          </Link>
          <nav className="hidden items-center gap-1 overflow-x-auto lg:flex">
            {nav.map((item) => {
              const active =
                item.href === "/app"
                  ? pathname === "/app"
                  : pathname.startsWith(item.href);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`rounded-full px-3.5 py-1.5 text-sm transition ${
                    active
                      ? "bg-charcoal text-soft-white"
                      : "text-muted hover:bg-ivory-deep hover:text-charcoal"
                  }`}
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>
          <div className="flex items-center gap-2">
            <span className="hidden max-w-[10rem] truncate rounded-full bg-ivory-deep px-3 py-1 text-xs text-chocolate sm:inline">
              {profile?.displayName}
            </span>
            <Button variant="ghost" onClick={() => signOut()}>
              Sign out
            </Button>
          </div>
        </div>
      </header>

      <main className="mx-auto w-full max-w-6xl px-4 py-6 md:px-6 md:py-10">
        {children}
      </main>

      <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-border/80 bg-soft-white/95 px-2 py-2 backdrop-blur-xl lg:hidden">
        <div className="mx-auto flex max-w-lg justify-between gap-1">
          {nav.slice(0, 5).map((item) => {
            const active =
              item.href === "/app"
                ? pathname === "/app"
                : pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex-1 rounded-xl px-1 py-2 text-center text-[11px] ${
                  active
                    ? "bg-blush/80 text-burgundy"
                    : "text-muted"
                }`}
              >
                {item.label}
              </Link>
            );
          })}
        </div>
      </nav>
    </div>
  );
}
