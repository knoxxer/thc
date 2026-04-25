import { timeAgo } from "@/lib/format";

interface Props {
  ranAt: string | null;
  status: "success" | "partial" | "failed" | null;
}

const STALE_HOURS = 25;

export default function SyncStatusBadge({ ranAt, status }: Props) {
  if (!ranAt) {
    return (
      <p className="text-xs text-muted">
        <span className="inline-block w-2 h-2 rounded-full bg-gray-500 mr-1.5 align-middle" />
        GHIN sync: never run
      </p>
    );
  }

  const ageHours = (Date.now() - new Date(ranAt).getTime()) / 3_600_000;
  const stale = ageHours > STALE_HOURS;

  let color = "bg-emerald-500";
  let label = `GHIN sync: ${timeAgo(ranAt)} ago`;

  if (status === "failed") {
    color = "bg-red-500";
    label = `GHIN sync failed ${timeAgo(ranAt)} ago`;
  } else if (stale) {
    color = "bg-red-500";
    label = `GHIN sync: ${timeAgo(ranAt)} ago — stale`;
  } else if (status === "partial") {
    color = "bg-yellow-500";
    label = `GHIN sync: ${timeAgo(ranAt)} ago — partial`;
  }

  return (
    <p className="text-xs text-muted">
      <span
        className={`inline-block w-2 h-2 rounded-full ${color} mr-1.5 align-middle`}
      />
      {label}
    </p>
  );
}
