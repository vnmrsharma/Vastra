"use client";

import Link from "next/link";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/Button";
import { useAuth } from "@/lib/auth/AuthProvider";

export default function LandingPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && user) router.replace("/app");
  }, [loading, user, router]);

  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="vastra-grid pointer-events-none absolute inset-0 opacity-35" />
      <div className="relative mx-auto flex min-h-screen max-w-5xl flex-col justify-center px-6 py-16">
        <div className="fade-up">
          <span className="pill">AI wardrobe · YouCam try-on</span>
          <h1 className="mt-5 font-display text-6xl leading-[0.92] text-charcoal md:text-8xl">
            Vastra
          </h1>
          <p className="mt-6 max-w-xl text-lg leading-relaxed text-chocolate/90 md:text-xl">
            Find the look. Shop your wardrobe. Virtually try what is missing —
            a soft, synced dressing room that feels as good as it looks.
          </p>
          <div className="mt-10 flex flex-wrap gap-3">
            <Link href="/signup">
              <Button>Start styling</Button>
            </Link>
            <Link href="/login">
              <Button variant="secondary">Sign in</Button>
            </Link>
          </div>
        </div>

        <ul className="fade-up-delay mt-16 grid gap-4 md:grid-cols-3">
          {[
            { t: "Your closet, live", d: "Upload pieces once — everything stays in sync." },
            { t: "Dress for the day", d: "Occasion + weather, styled from what you own." },
            { t: "Try before you buy", d: "Real YouCam virtual try-on, not a mock." },
          ].map((item) => (
            <li key={item.t} className="surface p-5">
              <p className="font-display text-xl text-charcoal">{item.t}</p>
              <p className="mt-2 text-sm text-muted">{item.d}</p>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
