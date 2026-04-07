export function timeAgo(dateStr: string): string {
  const seconds = Math.floor(
    (Date.now() - new Date(dateStr).getTime()) / 1000
  );
  if (seconds < 60) return "just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  return `${days}d`;
}

export function formatVsPar(netVsPar: number): string {
  if (netVsPar === 0) return "E";
  return netVsPar > 0 ? `+${netVsPar}` : `${netVsPar}`;
}

export function sendNotification(payload: {
  type: string;
  targetPlayerId?: string;
  notifyAll?: boolean;
  title: string;
  notifBody?: string;
  link?: string;
}) {
  fetch("/api/notifications", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  }).catch(() => {});
}
