import type { ReactNode } from "react";

export function EmptyState({
  title,
  description,
  action,
  emoji = "✧",
}: {
  title: string;
  description: string;
  action?: ReactNode;
  emoji?: string;
}) {
  return (
    <div className="surface fade-up px-6 py-14 text-center">
      <div className="floaty mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-blush/60 text-xl text-burgundy">
        {emoji}
      </div>
      <h3 className="font-display text-2xl text-charcoal">{title}</h3>
      <p className="mx-auto mt-2 max-w-sm text-sm text-muted">{description}</p>
      {action ? <div className="mt-6 flex justify-center">{action}</div> : null}
    </div>
  );
}
