import type { Notification } from "./types";

export function sendNotification(payload: {
  type: Notification["type"];
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
