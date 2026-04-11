import { createClient, type SupabaseClient } from "@supabase/supabase-js";

let _client: SupabaseClient | null = null;

export function getServiceClient() {
  if (!_client) {
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!key) {
      throw new Error("SUPABASE_SERVICE_ROLE_KEY is not set — cannot create service client");
    }
    _client = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, key);
  }
  return _client;
}
