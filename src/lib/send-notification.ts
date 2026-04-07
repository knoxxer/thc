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
