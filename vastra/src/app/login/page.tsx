import Link from "next/link";
import { Suspense } from "react";
import { LoginForm } from "./LoginForm";

export default function LoginPage() {
  return (
    <div className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-12">
      <Link href="/" className="font-display text-3xl text-charcoal">
        Vastra
      </Link>
      <div className="surface mt-8 p-6">
        <h1 className="font-display text-4xl">Welcome back</h1>
        <p className="mt-2 text-sm text-muted">
          Sign in with email and password — your closet stays synced.
        </p>
        <Suspense fallback={<p className="mt-8 text-sm text-muted">Loading…</p>}>
          <LoginForm />
        </Suspense>
      </div>
    </div>
  );
}
